import { UserRole } from '@prisma/client';

export class UserProfileDto {
  id: string;
  email: string;
  role: UserRole;
  orgId: string;
  createdAt: Date;
}
