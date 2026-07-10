import { UserRole } from '@prisma/client';

/**
 * Numeric rank per role — higher outranks lower. Single source of truth
 * for "X+" comparisons; nothing else should hardcode this ordering.
 */
export const ROLE_RANK: Record<UserRole, number> = {
  viewer: 0,
  editor: 1,
  admin: 2,
  owner: 3,
};

export function roleMeetsMinimum(
  actual: UserRole,
  minimum: UserRole,
): boolean {
  return ROLE_RANK[actual] >= ROLE_RANK[minimum];
}
