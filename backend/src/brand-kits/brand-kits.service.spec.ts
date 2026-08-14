import { BrandKitsService } from './brand-kits.service';

describe('BrandKitsService', () => {
  let service: BrandKitsService;
  let prisma: { brandKit: { upsert: jest.Mock } };

  beforeEach(() => {
    prisma = {
      brandKit: {
        upsert: jest.fn((args) => ({
          id: 'bk_1',
          orgId: args.where.orgId,
          colors: [],
          fonts: [],
          logoUrl: null,
          logoPublicId: null,
          ...args.create,
          ...args.update,
        })),
      },
    };
    service = new BrandKitsService(prisma as never);
  });

  describe('getForOrg', () => {
    it('upserts on the org so a first read materialises an empty kit', async () => {
      const kit = await service.getForOrg('org_1');

      const args = prisma.brandKit.upsert.mock.calls[0][0];
      expect(args.where).toEqual({ orgId: 'org_1' });
      expect(args.create).toEqual({ orgId: 'org_1' });
      expect(args.update).toEqual({}); // read must not mutate an existing kit
      expect(kit.colors).toEqual([]);
    });
  });

  describe('update', () => {
    it('writes only the fields present on the DTO', async () => {
      await service.update('org_1', { colors: ['#112233'] });

      const args = prisma.brandKit.upsert.mock.calls[0][0];
      expect(args.update).toEqual({ colors: ['#112233'] });
      // fonts/logo were not sent, so they must not appear in the update.
      expect(args.update).not.toHaveProperty('fonts');
      expect(args.update).not.toHaveProperty('logoUrl');
    });

    it('treats an explicit empty array as a clear, not a no-op', async () => {
      await service.update('org_1', { colors: [], fonts: [] });

      const args = prisma.brandKit.upsert.mock.calls[0][0];
      expect(args.update).toEqual({ colors: [], fonts: [] });
    });

    it('persists a logo url + publicId together', async () => {
      await service.update('org_1', {
        logoUrl: 'https://cdn.test/logo.png',
        logoPublicId: 'socialhub/logo',
      });

      const args = prisma.brandKit.upsert.mock.calls[0][0];
      expect(args.update).toEqual({
        logoUrl: 'https://cdn.test/logo.png',
        logoPublicId: 'socialhub/logo',
      });
      // And the create branch carries the org id so a first-touch PATCH works.
      expect(args.create.orgId).toBe('org_1');
    });
  });
});
