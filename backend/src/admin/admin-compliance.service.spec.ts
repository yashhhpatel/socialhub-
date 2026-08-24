import { NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { AdminComplianceService } from './admin-compliance.service';

describe('AdminComplianceService', () => {
  let service: AdminComplianceService;
  let prisma: {
    dataDeletionRequest: { count: jest.Mock; findMany: jest.Mock };
    organization: { findUnique: jest.Mock; update: jest.Mock };
  };

  beforeEach(() => {
    prisma = {
      dataDeletionRequest: {
        count: jest.fn().mockResolvedValue(0),
        findMany: jest.fn().mockResolvedValue([]),
      },
      organization: { findUnique: jest.fn(), update: jest.fn() },
    };
    service = new AdminComplianceService(prisma as unknown as PrismaService);
  });

  it('lists data-deletion requests (paginated)', async () => {
    prisma.dataDeletionRequest.count.mockResolvedValue(3);
    const res = await service.dataDeletionRequests({ page: 1, limit: 25 });
    expect(res.total).toBe(3);
  });

  it('suspend sets status + suspendedAt', async () => {
    prisma.organization.findUnique.mockResolvedValue({ id: 'o1' });
    prisma.organization.update.mockResolvedValue({
      id: 'o1',
      status: 'suspended',
      suspendedAt: new Date(),
    });
    const res = await service.suspendOrg('o1');
    expect(res.status).toBe('suspended');
    expect(prisma.organization.update.mock.calls[0][0].data.status).toBe('suspended');
    expect(prisma.organization.update.mock.calls[0][0].data.suspendedAt).toBeInstanceOf(Date);
  });

  it('reactivate clears suspendedAt', async () => {
    prisma.organization.findUnique.mockResolvedValue({ id: 'o1' });
    prisma.organization.update.mockResolvedValue({
      id: 'o1',
      status: 'active',
      suspendedAt: null,
    });
    const res = await service.reactivateOrg('o1');
    expect(res.status).toBe('active');
    expect(prisma.organization.update.mock.calls[0][0].data.suspendedAt).toBeNull();
  });

  it('404s for an unknown org', async () => {
    prisma.organization.findUnique.mockResolvedValue(null);
    await expect(service.suspendOrg('nope')).rejects.toBeInstanceOf(NotFoundException);
  });
});
