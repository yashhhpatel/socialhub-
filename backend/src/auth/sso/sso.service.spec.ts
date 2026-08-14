import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';

const mockValidate = jest.fn();
const mockAuthorizeUrl = jest.fn();

// The node-saml boundary is mocked — there is no live IdP in CI, so we stub
// the assertion validation exactly where a real integration would.
jest.mock('@node-saml/node-saml', () => ({
  SAML: jest.fn().mockImplementation(() => ({
    validatePostResponseAsync: mockValidate,
    getAuthorizeUrlAsync: mockAuthorizeUrl,
  })),
}));

import { SsoService } from './sso.service';

describe('SsoService', () => {
  let service: SsoService;
  let prisma: { ssoConfig: { findUnique: jest.Mock } };
  let users: { findByEmail: jest.Mock };
  let auth: { issueSession: jest.Mock };

  const config = {
    orgId: 'org_1',
    enabled: true,
    entryPoint: 'https://idp.example.com/sso',
    idpCert: 'CERT',
    issuer: 'socialhub',
  };

  beforeEach(() => {
    mockValidate.mockReset();
    mockAuthorizeUrl.mockReset();
    prisma = { ssoConfig: { findUnique: jest.fn().mockResolvedValue(config) } };
    users = { findByEmail: jest.fn() };
    auth = { issueSession: jest.fn().mockResolvedValue({ accessToken: 'a', refreshToken: 'r' }) };
    const configService = { get: jest.fn((_k, d) => d) };
    service = new SsoService(prisma as never, users as never, auth as never, configService as never);
  });

  describe('handleCallback', () => {
    it('validates the assertion, resolves the member, and issues a session', async () => {
      mockValidate.mockResolvedValue({ profile: { email: 'Sam@Ex.com' } });
      users.findByEmail.mockResolvedValue({
        id: 'u1',
        email: 'sam@ex.com',
        role: UserRole.editor,
        orgId: 'org_1',
      });

      const session = await service.handleCallback('SAML_XML', 'org_1');

      // Email is normalized before lookup.
      expect(users.findByEmail).toHaveBeenCalledWith('sam@ex.com');
      expect(auth.issueSession).toHaveBeenCalledWith('u1', 'sam@ex.com', UserRole.editor, 'org_1');
      expect(session.accessToken).toBe('a');
    });

    it('falls back to the nameID when no email attribute is present', async () => {
      mockValidate.mockResolvedValue({ profile: { nameID: 'nameid@ex.com' } });
      users.findByEmail.mockResolvedValue({ id: 'u1', email: 'nameid@ex.com', role: UserRole.viewer, orgId: 'org_1' });
      await service.handleCallback('SAML_XML', 'org_1');
      expect(users.findByEmail).toHaveBeenCalledWith('nameid@ex.com');
    });

    it('rejects a response whose signature/format fails validation', async () => {
      mockValidate.mockRejectedValue(new Error('invalid signature'));
      await expect(service.handleCallback('bad', 'org_1')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
      expect(auth.issueSession).not.toHaveBeenCalled();
    });

    it('rejects an identity that is not a member of the org', async () => {
      mockValidate.mockResolvedValue({ profile: { email: 'outsider@ex.com' } });
      users.findByEmail.mockResolvedValue({ id: 'u9', email: 'outsider@ex.com', role: UserRole.editor, orgId: 'other_org' });
      await expect(service.handleCallback('SAML_XML', 'org_1')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('rejects a response carrying no email', async () => {
      mockValidate.mockResolvedValue({ profile: {} });
      await expect(service.handleCallback('SAML_XML', 'org_1')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });

    it('400s when RelayState (the org) is missing', async () => {
      await expect(service.handleCallback('SAML_XML', '')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });

    it('400s when the org has no enabled SSO config', async () => {
      prisma.ssoConfig.findUnique.mockResolvedValue({ ...config, enabled: false });
      await expect(service.handleCallback('SAML_XML', 'org_1')).rejects.toBeInstanceOf(
        BadRequestException,
      );
    });
  });

  describe('buildLoginUrl', () => {
    it('asks the IdP for an authorize URL with the org id as RelayState', async () => {
      mockAuthorizeUrl.mockResolvedValue('https://idp.example.com/sso?SAMLRequest=...');
      const url = await service.buildLoginUrl('org_1', 'app.example.com');
      expect(mockAuthorizeUrl).toHaveBeenCalledWith('org_1', 'app.example.com', {});
      expect(url).toContain('idp.example.com');
    });
  });
});
