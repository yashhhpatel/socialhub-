import { WhiteLabelService } from './white-label.service';

describe('WhiteLabelService', () => {
  let service: WhiteLabelService;
  let prisma: { organization: { findUnique: jest.Mock; update: jest.Mock } };

  beforeEach(() => {
    prisma = {
      organization: {
        findUnique: jest.fn(),
        update: jest.fn((args) => ({
          whiteLabelLogoUrl: null,
          whiteLabelPrimaryColor: null,
          ...args.data,
        })),
      },
    };
    service = new WhiteLabelService(prisma as never);
  });

  describe('get', () => {
    it('returns the org branding', async () => {
      prisma.organization.findUnique.mockResolvedValue({
        whiteLabelLogoUrl: 'https://cdn.test/logo.png',
        whiteLabelPrimaryColor: '#1A2B3C',
      });
      expect(await service.get('org_1')).toEqual({
        logoUrl: 'https://cdn.test/logo.png',
        primaryColor: '#1A2B3C',
      });
    });

    it('defaults to null branding for an org that set none', async () => {
      prisma.organization.findUnique.mockResolvedValue({
        whiteLabelLogoUrl: null,
        whiteLabelPrimaryColor: null,
      });
      expect(await service.get('org_1')).toEqual({ logoUrl: null, primaryColor: null });
    });
  });

  describe('set', () => {
    it('writes only the provided fields', async () => {
      await service.set('org_1', { primaryColor: '#FF0000' });
      const data = prisma.organization.update.mock.calls[0][0].data;
      expect(data).toEqual({ whiteLabelPrimaryColor: '#FF0000' });
      expect(data).not.toHaveProperty('whiteLabelLogoUrl');
    });

    it('treats explicit null as clearing a field', async () => {
      await service.set('org_1', { logoUrl: null, primaryColor: null });
      const data = prisma.organization.update.mock.calls[0][0].data;
      expect(data).toEqual({ whiteLabelLogoUrl: null, whiteLabelPrimaryColor: null });
    });
  });
});
