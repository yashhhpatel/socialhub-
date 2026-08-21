/**
 * Builds the name for the workspace auto-created on signup (Option A — the
 * Organization relation is required, so every user must own an org, but we no
 * longer prompt for its name). Derived from the email local-part, e.g.
 * "ada.lovelace@x.com" -> "ada.lovelace's workspace". Renameable later in
 * settings. Shared by email signup (AuthService) and Google signup
 * (GoogleAuthService) so both paths name workspaces identically.
 */
export function defaultOrgName(email: string): string {
  const localPart = email.trim().toLowerCase().split('@')[0] || 'my';
  return `${localPart}'s workspace`;
}
