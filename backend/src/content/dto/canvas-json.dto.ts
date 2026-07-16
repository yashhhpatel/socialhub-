import { IsArray, IsNumber, Min } from 'class-validator';

/**
 * Deliberately minimal — per docs/api/SocialHub_REST_API_Design.md,
 * `canvasJson` must match width/height/layers, but the actual shape of
 * a layer is the editor's concern (Milestone 3.3+), not something this
 * milestone should guess at. `layers` is validated as an array of
 * unknown-shaped entries for now, not further specified.
 */
export class CanvasJsonDto {
  @IsNumber()
  @Min(1)
  width: number;

  @IsNumber()
  @Min(1)
  height: number;

  @IsArray()
  layers: unknown[];
}
