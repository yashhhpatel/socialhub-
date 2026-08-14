export class UploadMediaResponseDto {
  url: string;

  /**
   * Cloudinary's identifier for the stored image. Returned alongside the
   * URL from Milestone 4.1 because variant generation addresses
   * transformations by public id — deriving one by parsing a delivery
   * URL apart is brittle (the URL embeds version and transformation
   * segments that vary).
   *
   * The editor persists this back onto the asset as masterImagePublicId
   * via PATCH /content/assets/:id.
   */
  publicId: string;

  /**
   * A still frame for a video upload (Milestone 9.2) — the poster the
   * canvas video layer shows and the master render bakes in. Null for an
   * image upload, which is its own poster.
   */
  posterUrl?: string;
}
