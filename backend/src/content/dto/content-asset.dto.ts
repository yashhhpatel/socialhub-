import { ApprovalStatus, ContentAssetType } from '@prisma/client';

export class ContentAssetDto {
  id: string;
  orgId: string;
  createdById: string;
  type: ContentAssetType;
  canvasJson: unknown;
  approvalStatus: ApprovalStatus;
  createdAt: Date;
  updatedAt: Date;
}
