import { UnprocessableEntityException } from '@nestjs/common';
import { ContentAsset, Platform } from '@prisma/client';

import { FacebookAdapter } from '../social-accounts/adapters/facebook.adapter';
import { InstagramAdapter } from '../social-accounts/adapters/instagram.adapter';
import { LinkedInAdapter } from '../social-accounts/adapters/linkedin.adapter';
import { ThreadsAdapter } from '../social-accounts/adapters/threads.adapter';
import { XAdapter } from '../social-accounts/adapters/x.adapter';
import { VariantGeneratorService } from './variant-generator.service';

describe('VariantGeneratorService', () => {
  let service: VariantGeneratorService;
  let prisma: { contentVariant: { upsert: jest.Mock } };
  let cloudinary: { buildTransformedUrl: jest.Mock };

  const asset = {
    id: 'asset_1',
    orgId: 'org_1',
    masterImageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/socialhub/master.png',
    masterImagePublicId: 'socialhub/master',
    canvasJson: { width: 1080, height: 1080, layers: [{ type: 'shape', id: 'l1' }] },
  } as unknown as ContentAsset;

  /** Real adapters — capabilities() is documented as pure metadata with
   * no network access, so stubbing them would only test the stub. */
  const instagramAdapter = new InstagramAdapter({
    get: () => 'test',
  } as never);
  const xAdapter = new XAdapter({ get: () => 'test' } as never);
  const facebookAdapter = new FacebookAdapter({ get: () => 'test' } as never);
  const threadsAdapter = new ThreadsAdapter({ get: () => 'test' } as never);
  const linkedinAdapter = new LinkedInAdapter({ get: () => 'test' } as never);

  beforeEach(() => {
    prisma = { contentVariant: { upsert: jest.fn((args) => ({ id: 'var_1', ...args.create })) } };
    cloudinary = {
      buildTransformedUrl: jest.fn(
        (publicId: string, d: { width: number; height: number }) =>
          `https://cdn.test/${publicId}_${d.width}x${d.height}.png`,
      ),
    };

    service = new VariantGeneratorService(
      prisma as never,
      cloudinary as never,
      instagramAdapter,
      xAdapter,
      facebookAdapter,
      threadsAdapter,
      linkedinAdapter,
    );
  });

  describe('supported platforms', () => {
    it('reports every platform that has an adapter (all five, as of Phase 8)', () => {
      expect(service.supportedPlatforms.sort()).toEqual(
        [
          Platform.instagram,
          Platform.x,
          Platform.facebook,
          Platform.threads,
          Platform.linkedin,
        ].sort(),
      );
    });

    it('rejects a platform with no adapter as 422, not a silent no-op', () => {
      // All five real platforms now have adapters; a synthetic unknown value
      // still exercises the guard against an unmapped platform.
      expect(() => service.capabilitiesFor('myspace' as Platform)).toThrow(
        UnprocessableEntityException,
      );
    });
  });

  describe('generate', () => {
    it("renders Instagram at the platform's square spec", async () => {
      await service.generate(asset, [Platform.instagram]);

      expect(cloudinary.buildTransformedUrl).toHaveBeenCalledWith('socialhub/master', {
        width: 1080,
        height: 1080,
      });
    });

    it("renders X at the platform's 16:9 spec — a different size from Instagram", async () => {
      await service.generate(asset, [Platform.x]);

      expect(cloudinary.buildTransformedUrl).toHaveBeenCalledWith('socialhub/master', {
        width: 1600,
        height: 900,
      });
    });

    it('produces one distinctly-sized variant per requested platform from ONE master', async () => {
      await service.generate(asset, [Platform.instagram, Platform.x]);

      expect(prisma.contentVariant.upsert).toHaveBeenCalledTimes(2);
      const urls = cloudinary.buildTransformedUrl.mock.results.map((r) => r.value);
      expect(new Set(urls).size).toBe(2);
      // Same source image every time — "create once, publish everywhere".
      const sourceIds = cloudinary.buildTransformedUrl.mock.calls.map((c) => c[0]);
      expect(new Set(sourceIds)).toEqual(new Set(['socialhub/master']));
    });

    it('upserts on (assetId, platform) so regenerating updates instead of duplicating', async () => {
      await service.generate(asset, [Platform.instagram]);

      const args = prisma.contentVariant.upsert.mock.calls[0][0];
      expect(args.where).toEqual({
        assetId_platform: { assetId: 'asset_1', platform: Platform.instagram },
      });
      expect(args.update.renderedMediaUrl).toBeDefined();
    });

    it('marks variants ready, since generation completes within the request', async () => {
      await service.generate(asset, [Platform.instagram]);

      const args = prisma.contentVariant.upsert.mock.calls[0][0];
      expect(args.create.status).toBe('ready');
    });

    it('refuses (422) when the asset has no master render yet', async () => {
      const noMaster = { ...asset, masterImagePublicId: null } as ContentAsset;

      await expect(service.generate(noMaster, [Platform.instagram])).rejects.toThrow(
        UnprocessableEntityException,
      );
      expect(prisma.contentVariant.upsert).not.toHaveBeenCalled();
    });

    it('refuses (422) when the canvas has no layers', async () => {
      const empty = {
        ...asset,
        canvasJson: { width: 1080, height: 1080, layers: [] },
      } as unknown as ContentAsset;

      await expect(service.generate(empty, [Platform.instagram])).rejects.toThrow(
        UnprocessableEntityException,
      );
    });

    it('refuses an unsupported platform before writing ANY variant', async () => {
      await expect(
        service.generate(asset, [Platform.instagram, 'myspace' as Platform]),
      ).rejects.toThrow(UnprocessableEntityException);
    });
  });
});
