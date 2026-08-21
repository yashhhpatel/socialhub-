/// A media-library item returned by /media (Phase 19).
export class MediaAssetDto {
  id: string;
  url: string;
  publicId: string;
  type: string;
  name: string;
  posterUrl: string | null;
  createdAt: Date;
}
