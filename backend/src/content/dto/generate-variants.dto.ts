import { Platform } from '@prisma/client';
import { ArrayNotEmpty, ArrayUnique, IsArray, IsEnum } from 'class-validator';

/**
 * Mirrors docs/SocialHub_REST_API_Design.md, POST
 * /content/assets/:id/variants: `platforms` is a non-empty array of
 * supported enum values.
 *
 * ArrayUnique because asking for the same platform twice in one request
 * is a client bug, and silently deduping it would hide that. Whether a
 * requested platform is actually *implemented* is a separate check
 * (VariantGeneratorService.capabilitiesFor) — that's a 422 about product
 * state, not a 400 about request shape.
 */
export class GenerateVariantsDto {
  @IsArray()
  @ArrayNotEmpty({ message: 'Select at least one platform.' })
  @ArrayUnique({ message: 'Each platform may only be listed once.' })
  @IsEnum(Platform, { each: true, message: 'Unknown platform.' })
  platforms: Platform[];
}
