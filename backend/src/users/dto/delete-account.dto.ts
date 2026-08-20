import { IsNotEmpty, IsString } from 'class-validator';

/// Body for DELETE /users/me — the current password, re-confirmed because
/// account deletion is irreversible (Phase 17.4).
export class DeleteAccountDto {
  @IsString()
  @IsNotEmpty({ message: 'Your password is required to delete your account.' })
  password: string;
}
