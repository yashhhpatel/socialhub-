import { IsIn, IsOptional, IsUUID } from 'class-validator';

import { CaptionTone } from '../prompts/caption.prompt';

const TONES: CaptionTone[] = [
  'casual',
  'professional',
  'playful',
  'inspirational',
  'bold',
];

/** Mirrors docs/SocialHub_REST_API_Design.md, POST /ai/caption. */
export class GenerateCaptionDto {
  @IsUUID()
  assetId: string;

  @IsOptional()
  @IsIn(TONES, { message: `tone must be one of: ${TONES.join(', ')}.` })
  tone?: CaptionTone;
}

export class GenerateCaptionResponseDto {
  caption: string;
}
