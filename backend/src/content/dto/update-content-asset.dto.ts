import { Type } from 'class-transformer';
import { IsOptional, IsString, IsUrl, ValidateNested } from 'class-validator';

import { CanvasJsonDto } from './canvas-json.dto';

export class UpdateContentAssetDto {
  @IsOptional()
  @ValidateNested()
  @Type(() => CanvasJsonDto)
  canvasJson?: CanvasJsonDto;

  /**
   * The flattened render of the canvas, produced and uploaded by the
   * editor (Milestone 4.1). Both fields come straight from the
   * POST /content/assets/upload response.
   *
   * Optional and independent of canvasJson so the editor's debounced
   * autosave (Milestone 3.5) can keep PATCHing canvas state without
   * re-uploading an image on every change — the master render is
   * refreshed only when the design is actually exported.
   */
  @IsOptional()
  @IsUrl({ require_tld: false }, { message: 'masterImageUrl must be a valid URL.' })
  masterImageUrl?: string;

  @IsOptional()
  @IsString()
  masterImagePublicId?: string;
}
