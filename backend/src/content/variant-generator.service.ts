import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { ContentAsset, ContentVariant, Platform, VariantStatus } from '@prisma/client';

import { CloudinaryService } from '../media/cloudinary.service';
import {
  PlatformAdapter,
  PlatformCapabilities,
} from '../social-accounts/adapters/adapter.interface';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Produces one platform-specific rendition per requested platform
 * (Milestone 4.1).
 *
 * PIPELINE: the editor rasterizes its own canvas and uploads the result
 * via POST /content/assets/upload, storing it on the asset as
 * masterImageUrl/masterImagePublicId. This service then derives each
 * platform's rendition as a Cloudinary transformation of that single
 * master.
 *
 * The backend deliberately does NOT rasterize canvasJson itself. Doing so
 * would mean reimplementing the Flutter canvas engine in Node — a second
 * renderer that would drift from the one users actually see, turning
 * "what I designed" and "what got published" into two different images.
 * Rendering once, in the engine that owns the canvas, is what makes the
 * handoff lossless (docs/SocialHub_Architecture_Plan.md opens on exactly
 * this seam).
 *
 * SYNCHRONOUS FOR NOW: variants reach `ready` within the request.
 * VariantStatus.pending and the endpoint's 202 exist because Phase 7
 * moves generation onto a queue; keeping the documented contract stable
 * now means the frontend needs no change when that lands.
 */
@Injectable()
export class VariantGeneratorService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cloudinary: CloudinaryService,
    instagramAdapter: InstagramAdapter,
    xAdapter: XAdapter,
  ) {
    // Direct injection rather than a registry, matching how
    // SocialAccountsService already composes adapters. A real registry
    // earns its keep at five adapters (Phase 8), not two.
    this.adapters = {
      [Platform.instagram]: instagramAdapter,
      [Platform.x]: xAdapter,
    };
  }

  private readonly adapters: Partial<Record<Platform, PlatformAdapter>>;

  /**
   * Platforms this service can currently render for. Facebook, Threads
   * and LinkedIn have no adapter until Phase 8, so requesting them is a
   * client error rather than a silent no-op that produces a variant
   * nothing can publish.
   */
  get supportedPlatforms(): Platform[] {
    return Object.keys(this.adapters) as Platform[];
  }

  capabilitiesFor(platform: Platform): PlatformCapabilities {
    const adapter = this.adapters[platform];
    if (!adapter) {
      throw new UnprocessableEntityException(
        `${platform} is not supported yet. Supported platforms: ${this.supportedPlatforms.join(', ')}.`,
      );
    }
    return adapter.capabilities();
  }

  /**
   * Generates (or regenerates) variants for the given asset.
   *
   * Upserts on (assetId, platform) so pressing "generate" twice updates
   * the existing rendition instead of accumulating duplicates that would
   * make publish targeting ambiguous.
   */
  async generate(asset: ContentAsset, platforms: Platform[]): Promise<ContentVariant[]> {
    this.assertRenderable(asset);

    const variants: ContentVariant[] = [];

    for (const platform of platforms) {
      const { imageSpec } = this.capabilitiesFor(platform);

      const renderedMediaUrl = this.cloudinary.buildTransformedUrl(
        asset.masterImagePublicId as string,
        { width: imageSpec.width, height: imageSpec.height },
      );

      variants.push(
        await this.prisma.contentVariant.upsert({
          where: { assetId_platform: { assetId: asset.id, platform } },
          create: {
            assetId: asset.id,
            platform,
            renderedMediaUrl,
            status: VariantStatus.ready,
          },
          update: {
            renderedMediaUrl,
            status: VariantStatus.ready,
          },
        }),
      );
    }

    return variants;
  }

  /**
   * 422, not 400: the request itself is well-formed — the asset simply
   * isn't in a state that can produce a rendition yet. That distinction
   * matters to the client, which should prompt the user to finish and
   * save the design rather than report a malformed request.
   */
  private assertRenderable(asset: ContentAsset): void {
    if (!asset.masterImagePublicId) {
      throw new UnprocessableEntityException(
        'This asset has no rendered image yet. Save the design from the editor before generating platform variants.',
      );
    }

    const canvas = asset.canvasJson as { layers?: unknown[] } | null;
    if (!canvas || !Array.isArray(canvas.layers) || canvas.layers.length === 0) {
      throw new UnprocessableEntityException(
        'This asset has no layers. Add content to the design before generating platform variants.',
      );
    }
  }
}
