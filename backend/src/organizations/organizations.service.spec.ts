import { OrganizationsService } from './organizations.service';

describe('OrganizationsService.overview', () => {
  let service: OrganizationsService;
  let prisma: {
    organization: { findUnique: jest.Mock };
    user: { count: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      organization: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'org_1',
          name: 'Acme',
          planTier: 'free',
          requiresApproval: false,
        }),
      },
      user: { count: jest.fn().mockResolvedValue(3) },
    };
    service = new OrganizationsService(prisma as never);
  });

  it('returns name, plan, approval policy and member count', async () => {
    const result = await service.overview('org_1');
    expect(result).toEqual({
      id: 'org_1',
      name: 'Acme',
      planTier: 'free',
      requiresApproval: false,
      memberCount: 3,
    });
    expect(prisma.user.count).toHaveBeenCalledWith({ where: { orgId: 'org_1' } });
  });

  it('returns null for a missing org', async () => {
    prisma.organization.findUnique.mockResolvedValue(null);
    expect(await service.overview('missing')).toBeNull();
  });
});
