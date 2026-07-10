import { UserRole } from '@prisma/client';

export interface JwtPayload {
  sub: string; // userId
  email: string;
  role: UserRole;
  orgId: string;
}
