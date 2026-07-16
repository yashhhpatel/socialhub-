import { Type } from 'class-transformer';
import { IsIn, ValidateNested } from 'class-validator';

import { CanvasJsonDto } from './canvas-json.dto';

export class CreateContentAssetDto {
  @IsIn(['image', 'video'])
  type: 'image' | 'video';

  @ValidateNested()
  @Type(() => CanvasJsonDto)
  canvasJson: CanvasJsonDto;
}
