import { UnprocessableEntityException } from '@nestjs/common';
import { ContentAsset } from '@prisma/client';

interface CanvasLayer {
  type?: string;
  text?: unknown;
}

/**
 * Describes a design in words for an AI prompt (shared by caption and
 * hashtag generation). Extracted from CaptionService in Phase 12 so the
 * hashtag feature summarizes a design identically rather than growing a
 * second, drifting description.
 *
 * 422s on an empty canvas rather than asking the model to work from nothing,
 * per the REST design doc ("422 if asset has no visual content yet").
 * `emptyMessage` lets each caller phrase that for its own feature.
 */
export function summarizeCanvas(asset: ContentAsset, emptyMessage: string): string {
  const canvas = asset.canvasJson as { layers?: CanvasLayer[] } | null;
  const layers = Array.isArray(canvas?.layers) ? canvas.layers : [];

  if (layers.length === 0) {
    throw new UnprocessableEntityException(emptyMessage);
  }

  const texts = layers
    .filter((l) => l.type === 'text' && typeof l.text === 'string' && (l.text as string).trim())
    .map((l) => (l.text as string).trim());

  const imageCount = layers.filter((l) => l.type === 'image').length;
  const shapeCount = layers.filter((l) => l.type === 'shape').length;

  const parts: string[] = [];

  if (texts.length > 0) {
    parts.push(`Text on the design:\n${texts.map((t) => `- "${t}"`).join('\n')}`);
  }
  if (imageCount > 0) {
    parts.push(`${imageCount} image${imageCount === 1 ? '' : 's'} placed on the design.`);
  }
  if (shapeCount > 0) {
    parts.push(`${shapeCount} decorative shape${shapeCount === 1 ? '' : 's'}.`);
  }

  if (texts.length === 0) {
    parts.push(
      'The design contains no text, so its subject matter is not described here. Keep the output general rather than guessing at specifics.',
    );
  }

  return parts.join('\n\n');
}
