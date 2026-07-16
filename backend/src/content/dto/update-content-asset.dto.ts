import { Type } from 'class-transformer';
import { IsOptional, ValidateNested } from 'class-validator';

import { CanvasJsonDto } from './canvas-json.dto';

export class UpdateContentAssetDto {
  @IsOptional()
  @ValidateNested()
  @Type(() => CanvasJsonDto)
  canvasJson?: CanvasJsonDto;
}
