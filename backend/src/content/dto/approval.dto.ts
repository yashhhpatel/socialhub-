import { ApprovalStatus } from '@prisma/client';
import { IsBoolean, IsEnum } from 'class-validator';

/** PATCH /content/assets/:id/approval (Milestone 13.2). */
export class ChangeApprovalDto {
  @IsEnum(ApprovalStatus)
  status: ApprovalStatus;
}

/** PATCH /content/approval-policy (Milestone 13.2). */
export class SetApprovalPolicyDto {
  @IsBoolean()
  requiresApproval: boolean;
}
