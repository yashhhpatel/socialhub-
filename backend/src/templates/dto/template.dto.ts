/**
 * Gallery row (Milestone 9.4) — deliberately omits canvasJson, which can be
 * large. The list screen only needs enough to render a card; the full
 * design is fetched by id when the user actually starts from a template.
 */
export class TemplateSummaryDto {
  id!: string;
  name!: string;
  category!: string | null;
  thumbnailUrl!: string | null;
  createdAt!: Date;
  /**
   * Whether the calling org owns this template — the only ones it may delete.
   * Always true for the org's own library (`GET /templates`); per-row in the
   * marketplace, where most rows belong to other orgs.
   */
  isOwn!: boolean;
}

/** Full template including the canvas payload to clone into a new asset. */
export class TemplateDetailDto extends TemplateSummaryDto {
  canvasJson!: unknown;
}
