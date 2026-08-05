import { Injectable, NotFoundException } from '@nestjs/common';
import { ContentAsset, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CreateContentAssetDto } from './dto/create-content-asset.dto';
import { UpdateContentAssetDto } from './dto/update-content-asset.dto';

@Injectable()
export class ContentService {
  constructor(private readonly prisma: PrismaService) {}

  create(
    orgId: string,
    createdById: string,
    dto: CreateContentAssetDto,
  ): Promise<ContentAsset> {
    return this.prisma.contentAsset.create({
      data: {
        orgId,
        createdById,
        type: dto.type,
        canvasJson: dto.canvasJson as unknown as Prisma.InputJsonValue,
      },
    });
  }

  /**
   * Fetches an asset, scoped to the caller's org — returns 404 (never a
   * 403) if the asset belongs to a different org, so a caller can't
   * distinguish "doesn't exist" from "exists but isn't yours."
   */
  async findByIdScoped(id: string, orgId: string): Promise<ContentAsset> {
    const asset = await this.prisma.contentAsset.findUnique({ where: { id } });

    if (!asset || asset.orgId !== orgId) {
      throw new NotFoundException('Content asset not found.');
    }

    return asset;
  }

  /**
   * Same scoping rules as [findByIdScoped], but includes the asset's
   * per-platform variants.
   *
   * Separate from findByIdScoped rather than adding an include to it:
   * VariantGeneratorService calls that one on every generate request and
   * has no use for the variants it's about to overwrite, so folding the
   * join in there would make the hot path pay for data it discards.
   *
   * This is what GET /content/assets/:id returns — the REST design doc
   * specifies "full asset including nested variants summary", and the
   * 202 from POST :id/variants explicitly directs clients to poll this
   * endpoint, so omitting variants would leave that documented flow with
   * nothing to poll for.
   */
  async findByIdScopedWithVariants(id: string, orgId: string) {
    const asset = await this.prisma.contentAsset.findUnique({
      where: { id },
      include: {
        // Stable ordering so a polling client doesn't see rows shuffle
        // between requests.
        variants: { orderBy: { platform: 'asc' } },
      },
    });

    if (!asset || asset.orgId !== orgId) {
      throw new NotFoundException('Content asset not found.');
    }

    return asset;
  }

  /**
   * Autosave endpoint's backing method — deliberately accepts a partial
   * update (canvasJson optional) since the editor calls this on every
   * debounced change, not just full-document saves.
   */
  async update(
    id: string,
    orgId: string,
    dto: UpdateContentAssetDto,
  ): Promise<ContentAsset> {
    await this.findByIdScoped(id, orgId); // ownership check, 404s if not found/owned

    return this.prisma.contentAsset.update({
      where: { id },
      data: {
        ...(dto.canvasJson
          ? { canvasJson: dto.canvasJson as unknown as Prisma.InputJsonValue }
          : {}),
        // Spread conditionally, same as canvasJson: a PATCH that only
        // autosaves canvas state must not null out an existing master
        // render just because it didn't mention one.
        ...(dto.masterImageUrl !== undefined
          ? { masterImageUrl: dto.masterImageUrl }
          : {}),
        ...(dto.masterImagePublicId !== undefined
          ? { masterImagePublicId: dto.masterImagePublicId }
          : {}),
      },
    });
  }
}
