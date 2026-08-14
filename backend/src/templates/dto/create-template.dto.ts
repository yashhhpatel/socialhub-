import { Type } from 'class-transformer';
import {
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { CanvasJsonDto } from '../../content/dto/canvas-json.dto';

/**
 * Creates a template (Milestone 9.4). canvasJson reuses the same shared
 * contract ContentAsset validates against — a template is a saved starting
 * canvas, so the shape is identical.
 */
export class CreateTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  category?: string;

  @ValidateNested()
  @Type(() => CanvasJsonDto)
  canvasJson: CanvasJsonDto;

  @IsOptional()
  @IsUrl({ require_tld: false }, { message: 'thumbnailUrl must be a valid URL.' })
  thumbnailUrl?: string;
}
