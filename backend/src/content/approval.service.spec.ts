import { ForbiddenException, UnprocessableEntityException } from '@nestjs/common';
import { ApprovalStatus, UserRole } from '@prisma/client';

import { ApprovalService } from './approval.service';

describe('ApprovalService', () => {
  let service: ApprovalService;
  let prisma: {
    contentAsset: { update: jest.Mock };
    organization: { findUnique: jest.Mock; update: jest.Mock };
  };
  let content: { findByIdScoped: jest.Mock };

  const editor = { role: UserRole.editor };
  const admin = { role: UserRole.admin };

  function asset(status: ApprovalStatus) {
    return { id: 'asset_1', orgId: 'org_1', approvalStatus: status };
  }

  beforeEach(() => {
    prisma = {
      contentAsset: { update: jest.fn((args) => ({ id: 'asset_1', ...args.data })) },
      organization: {
        findUnique: jest.fn().mockResolvedValue({ requiresApproval: false }),
        update: jest.fn((args) => ({ requiresApproval: args.data.requiresApproval })),
      },
    };
    content = { findByIdScoped: jest.fn() };
    service = new ApprovalService(prisma as never, content as never);
  });

  describe('transition — state machine', () => {
    it('lets an editor submit a draft for approval', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.draft));
      const updated = await service.transition('org_1', 'asset_1', ApprovalStatus.pending_approval, editor);
      expect(updated.approvalStatus).toBe(ApprovalStatus.pending_approval);
    });

    it('rejects an illegal jump (draft -> approved)', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.draft));
      await expect(
        service.transition('org_1', 'asset_1', ApprovalStatus.approved, admin),
      ).rejects.toBeInstanceOf(UnprocessableEntityException);
    });

    it('lets an admin approve a pending design', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.pending_approval));
      const updated = await service.transition('org_1', 'asset_1', ApprovalStatus.approved, admin);
      expect(updated.approvalStatus).toBe(ApprovalStatus.approved);
    });

    it('forbids an editor from approving', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.pending_approval));
      await expect(
        service.transition('org_1', 'asset_1', ApprovalStatus.approved, editor),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(prisma.contentAsset.update).not.toHaveBeenCalled();
    });

    it('forbids an editor from rejecting', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.pending_approval));
      await expect(
        service.transition('org_1', 'asset_1', ApprovalStatus.rejected, editor),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('lets an editor withdraw an approved design back to draft', async () => {
      content.findByIdScoped.mockResolvedValue(asset(ApprovalStatus.approved));
      const updated = await service.transition('org_1', 'asset_1', ApprovalStatus.draft, editor);
      expect(updated.approvalStatus).toBe(ApprovalStatus.draft);
    });
  });

  describe('policy', () => {
    it('reads the org requiresApproval flag', async () => {
      prisma.organization.findUnique.mockResolvedValue({ requiresApproval: true });
      expect(await service.getPolicy('org_1')).toEqual({ requiresApproval: true });
    });

    it('sets the org requiresApproval flag', async () => {
      expect(await service.setPolicy('org_1', true)).toEqual({ requiresApproval: true });
      expect(prisma.organization.update).toHaveBeenCalledWith({
        where: { id: 'org_1' },
        data: { requiresApproval: true },
      });
    });
  });
});
