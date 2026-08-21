import { Injectable, NotFoundException } from '@nestjs/common';
import { MediaAsset } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

/// Persistence for the media library (Phase 19). The upload itself (Cloudinary
/// / video processing) stays in the controller; this owns the DB records so an
/// org's uploads survive across sessions.
@Injectable()
export class MediaService {
  constructor(private readonly prisma: PrismaService) {}

  record(params: {
    orgId: string;
    createdById: string;
    url: string;
    publicId: string;
    type: 'image' | 'video';
    name: string;
    posterUrl?: string;
  }): Promise<MediaAsset> {
    return this.prisma.mediaAsset.create({
      data: {
        orgId: params.orgId,
        createdById: params.createdById,
        url: params.url,
        publicId: params.publicId,
        type: params.type,
        name: params.name,
        posterUrl: params.posterUrl ?? null,
      },
    });
  }

  listForOrg(orgId: string): Promise<MediaAsset[]> {
    return this.prisma.mediaAsset.findMany({
      where: { orgId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// Deletes a media record, scoped to the org (404 for another org's id — same
  /// tenant-safety rule as social accounts / content). Returns nothing.
  async remove(id: string, orgId: string): Promise<void> {
    const asset = await this.prisma.mediaAsset.findUnique({ where: { id } });
    if (!asset || asset.orgId !== orgId) {
      throw new NotFoundException('Media not found.');
    }
    await this.prisma.mediaAsset.delete({ where: { id } });
  }
}
