import { Injectable } from '@nestjs/common';
import { BrandKit } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { UpdateBrandKitDto } from './dto/update-brand-kit.dto';

/**
 * Owns the single brand kit each org has (Milestone 9.3).
 *
 * Both operations are upserts keyed on the unique orgId, which makes the
 * kit "always exists" from the caller's point of view: GET never 404s (a
 * new org just sees an empty kit) and PATCH works whether or not a row has
 * been created yet. That removes an otherwise pointless "create the kit
 * first" step from the editor flow — there is exactly one kit per org, so
 * lazily materialising it on first touch is simpler than a separate POST.
 */
@Injectable()
export class BrandKitsService {
  constructor(private readonly prisma: PrismaService) {}

  /** The org's brand kit, creating an empty one on first read. */
  getForOrg(orgId: string): Promise<BrandKit> {
    return this.prisma.brandKit.upsert({
      where: { orgId },
      create: { orgId },
      update: {},
    });
  }

  /**
   * Applies a partial update. Only the fields present on the DTO are
   * written — `undefined` values are dropped so an omitted field keeps its
   * stored value, while an explicit empty array clears colours/fonts.
   */
  update(orgId: string, dto: UpdateBrandKitDto): Promise<BrandKit> {
    const data = {
      ...(dto.colors !== undefined ? { colors: dto.colors } : {}),
      ...(dto.fonts !== undefined ? { fonts: dto.fonts } : {}),
      ...(dto.logoUrl !== undefined ? { logoUrl: dto.logoUrl } : {}),
      ...(dto.logoPublicId !== undefined ? { logoPublicId: dto.logoPublicId } : {}),
    };

    return this.prisma.brandKit.upsert({
      where: { orgId },
      create: { orgId, ...data },
      update: data,
    });
  }
}
