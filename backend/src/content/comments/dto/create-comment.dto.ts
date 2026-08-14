import { IsString, MaxLength, MinLength } from 'class-validator';

/** POST /content/assets/:id/comments (Milestone 13.1). */
export class CreateCommentDto {
  @IsString()
  @MinLength(1, { message: 'A comment cannot be empty.' })
  @MaxLength(2000)
  body: string;
}

export class CommentDto {
  id: string;
  body: string;
  authorId: string;
  authorEmail: string;
  createdAt: Date;
}
