/**
 * NOTE: intentionally does NOT include `role`/`orgId` yet, unlike the
 * target shape documented in docs/api/SocialHub_REST_API_Design.md. Those
 * fields depend on Organization, which doesn't exist until Milestone 1.2.
 * This DTO will gain those fields in that milestone's commit, not before —
 * adding them now would mean returning fake/placeholder values, which is
 * worse than staging the API honestly across the two milestones.
 */
export class AuthUserDto {
  id: string;
  email: string;
}

export class AuthResponseDto {
  user: AuthUserDto;
  accessToken: string;
  refreshToken: string;
}
