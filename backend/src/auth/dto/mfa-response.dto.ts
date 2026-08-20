/**
 * Returned by POST /auth/login when the account has MFA enabled (Phase 17.3):
 * instead of a session, the caller gets a short-lived challenge token to
 * exchange — together with a TOTP or recovery code — at POST /auth/mfa/verify.
 * `mfaRequired: true` is the discriminator the frontend switches on.
 */
export class MfaChallengeResponseDto {
  mfaRequired: true;
  mfaChallengeToken: string;
}

/** Returned by POST /auth/mfa/setup — the secret to add to an authenticator. */
export class MfaSetupResponseDto {
  /** Base32 secret for manual entry. */
  secret: string;
  /** otpauth:// URI the frontend renders as a QR code. */
  otpauthUri: string;
}

/**
 * Returned by POST /auth/mfa/enable — the one and only time the plaintext
 * recovery codes are shown. They're stored hashed, so they can never be
 * displayed again.
 */
export class MfaEnabledResponseDto {
  recoveryCodes: string[];
}

/** Returned by GET /auth/mfa/status. */
export class MfaStatusDto {
  enabled: boolean;
  recoveryCodesRemaining: number;
}
