/**
 * API shape of a brand kit (Milestone 9.3). Mapped explicitly from the
 * Prisma row rather than returned raw, matching the convention used by the
 * other modules — the DB row and the wire contract are allowed to diverge.
 */
export class BrandKitDto {
  id!: string;
  colors!: string[];
  fonts!: string[];
  logoUrl!: string | null;
  logoPublicId!: string | null;
  updatedAt!: Date;
}
