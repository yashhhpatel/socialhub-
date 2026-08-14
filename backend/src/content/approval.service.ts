import {
  ForbiddenException,
  Injectable,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ApprovalStatus, ContentAsset, UserRole } from '@prisma/client';

import { roleMeetsMinimum } from '../common/constants/role-rank';
import { PrismaService } from '../prisma/prisma.service';
import { ContentService } from './content.service';

/**
 * Which statuses a given status can move to (Milestone 13.2). A small,
 * explicit state machine rather than "any status can be set" — so an asset
 * can't jump from draft straight to approved, skipping review, and the set
 * of legal moves is auditable in one place.
 *
 *   draft ─submit→ pending_approval ─approve→ approved
 *                        │  ─reject→ rejected
 *   approved ─withdraw→ draft        rejected ─resubmit→ pending_approval
 *   (any of pending/approved/rejected can drop back to draft to edit)
 */
const VALID_TRANSITIONS: Record<ApprovalStatus, ApprovalStatus[]> = {
  [ApprovalStatus.draft]: [ApprovalStatus.pending_approval],
  [ApprovalStatus.pending_approval]: [
    ApprovalStatus.approved,
    ApprovalStatus.rejected,
    ApprovalStatus.draft,
  ],
  [ApprovalStatus.approved]: [ApprovalStatus.draft],
  [ApprovalStatus.rejected]: [ApprovalStatus.draft, ApprovalStatus.pending_approval],
};

/** The verdict transitions are the admins' call; submit/withdraw are editors'. */
function minRoleFor(target: ApprovalStatus): UserRole {
  return target === ApprovalStatus.approved || target === ApprovalStatus.rejected
    ? UserRole.admin
    : UserRole.editor;
}

@Injectable()
export class ApprovalService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly content: ContentService,
  ) {}

  /**
   * Moves an asset to a new approval status, enforcing both the legal
   * transitions above and the role required for the destination (only
   * admin+ may approve/reject; editor+ may submit/withdraw).
   */
  async transition(
    orgId: string,
    assetId: string,
    target: ApprovalStatus,
    actor: { role: UserRole },
  ): Promise<ContentAsset> {
    const asset = await this.content.findByIdScoped(assetId, orgId); // 404s another org
    const current = asset.approvalStatus;

    if (!VALID_TRANSITIONS[current].includes(target)) {
      throw new UnprocessableEntityException(
        `An asset that is ${current} cannot move to ${target}.`,
      );
    }
    if (!roleMeetsMinimum(actor.role, minRoleFor(target))) {
      throw new ForbiddenException(
        target === ApprovalStatus.approved || target === ApprovalStatus.rejected
          ? 'Only an admin or owner can approve or reject a design.'
          : 'You do not have permission to change this approval status.',
      );
    }

    return this.prisma.contentAsset.update({
      where: { id: assetId },
      data: { approvalStatus: target },
    });
  }

  /** Whether this org gates publishing on approval. */
  async getPolicy(orgId: string): Promise<{ requiresApproval: boolean }> {
    const org = await this.prisma.organization.findUnique({ where: { id: orgId } });
    return { requiresApproval: org?.requiresApproval ?? false };
  }

  /** Turns the org-wide approval requirement on or off (admin+ at the route). */
  async setPolicy(orgId: string, requiresApproval: boolean): Promise<{ requiresApproval: boolean }> {
    const org = await this.prisma.organization.update({
      where: { id: orgId },
      data: { requiresApproval },
    });
    return { requiresApproval: org.requiresApproval };
  }
}
