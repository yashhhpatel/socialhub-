import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

import { CaptionTone } from '../prompts/caption.prompt';

const TONES: CaptionTone[] = [
  'casual',
  'professional',
  'playful',
  'inspirational',
  'bold',
];

/** POST /ai/tone (Milestone 12.1) — rewrite supplied copy in a target tone. */
export class ConvertToneDto {
  @IsString()
  @MinLength(1)
  // Bounded to a caption-sized input; this rewrites a post, not an essay.
  @MaxLength(5000)
  text: string;

  @IsIn(TONES, { message: `tone must be one of: ${TONES.join(', ')}.` })
  tone: CaptionTone;
}

export class ConvertToneResponseDto {
  text: string;
}
