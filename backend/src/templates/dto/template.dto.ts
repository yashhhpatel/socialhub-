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
}

/** Full template including the canvas payload to clone into a new asset. */
export class TemplateDetailDto extends TemplateSummaryDto {
  canvasJson!: unknown;
}
