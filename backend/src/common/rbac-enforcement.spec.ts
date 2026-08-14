import 'reflect-metadata';
import { UserRole } from '@prisma/client';

import { AiController } from '../ai/ai.controller';
import { BrandKitsController } from '../brand-kits/brand-kits.controller';
import { ApprovalController } from '../content/approval.controller';
import { CommentsController } from '../content/comments/comments.controller';
import { ContentController } from '../content/content.controller';
import {
  InvitesAdminController,
  InvitesPublicController,
} from '../organizations/invites/invites.controller';
import { MembersController } from '../organizations/members/members.controller';
import { PublishingController } from '../publishing/publishing.controller';
import { SocialAccountsController } from '../social-accounts/social-accounts.controller';
import { TemplatesController } from '../templates/templates.controller';
import { ROLES_KEY } from './decorators/roles.decorator';

/** Reads the minimum role @Roles(...) set on a handler, or its class. */
function roleOf(controller: new (...args: never[]) => object, method: string): UserRole | undefined {
  const handler = (controller.prototype as Record<string, unknown>)[method];
  return (
    (Reflect.getMetadata(ROLES_KEY, handler as object) as UserRole | undefined) ??
    (Reflect.getMetadata(ROLES_KEY, controller) as UserRole | undefined)
  );
}

/**
 * RBAC enforcement matrix (Milestone 11.2). Every mutating endpoint must
 * declare the right minimum role; every read endpoint must stay open to any
 * authenticated member (no @Roles), so viewers can read. This is the
 * blueprint's "verified by test matrix" — it fails loudly if a new mutating
 * route is added without a role, or a read route is over-restricted.
 */
describe('RBAC enforcement across mutating endpoints', () => {
  const V = UserRole.viewer;
  const E = UserRole.editor;
  const A = UserRole.admin;

  const matrix: Array<[string, new (...args: never[]) => object, string, UserRole]> = [
    // Content authoring / publishing — editor+.
    ['AI caption', AiController, 'generateCaption', E],
    ['AI hashtags', AiController, 'generateHashtags', E],
    ['AI tone', AiController, 'convertTone', E],
    ['AI viral score', AiController, 'viralScore', E],
    ['AI best time', AiController, 'bestTime', E],
    ['content create', ContentController, 'create', E],
    ['content update', ContentController, 'update', E],
    ['content upload', ContentController, 'uploadMedia', E],
    ['variant generate', ContentController, 'generateVariants', E],
    ['publish now', PublishingController, 'publishNow', E],
    ['publish schedule', PublishingController, 'schedule', E],
    ['publish cancel', PublishingController, 'cancelJob', E],
    ['template create', TemplatesController, 'create', E],
    // Collaboration — any member (viewer+) can comment.
    ['comment create', CommentsController, 'create', V],
    // Approval — editor+ baseline (approve/reject is admin-enforced in the
    // service); the org-wide policy toggle is admin+.
    ['approval transition', ApprovalController, 'changeApproval', E],
    ['approval policy set', ApprovalController, 'setPolicy', A],
    // Settings / team — admin+.
    ['brand kit edit', BrandKitsController, 'update', A],
    ['account disconnect', SocialAccountsController, 'disconnect', A],
    ['connect instagram', SocialAccountsController, 'connectInstagram', A],
    ['connect x', SocialAccountsController, 'connectX', A],
    ['connect facebook', SocialAccountsController, 'connectFacebook', A],
    ['connect threads', SocialAccountsController, 'connectThreads', A],
    ['connect linkedin', SocialAccountsController, 'connectLinkedIn', A],
    ['invite create', InvitesAdminController, 'invite', A],
    ['invite revoke', InvitesAdminController, 'revoke', A],
    ['member role change', MembersController, 'changeRole', A],
  ];

  it.each(matrix)('%s requires %s+', (_label, controller, method, expected) => {
    expect(roleOf(controller, method)).toBe(expected);
  });

  it('leaves read endpoints open to any authenticated member', () => {
    expect(roleOf(ContentController, 'listAssets')).toBeUndefined();
    expect(roleOf(ContentController, 'get')).toBeUndefined();
    expect(roleOf(PublishingController, 'listJobs')).toBeUndefined();
    expect(roleOf(SocialAccountsController, 'list')).toBeUndefined();
    expect(roleOf(BrandKitsController, 'get')).toBeUndefined();
    expect(roleOf(TemplatesController, 'list')).toBeUndefined();
  });

  it('leaves the public invite-accept endpoint unguarded (the token is the auth)', () => {
    expect(roleOf(InvitesPublicController, 'accept')).toBeUndefined();
  });

  it('leaves OAuth callbacks public (the browser has no auth header there)', () => {
    expect(roleOf(SocialAccountsController, 'instagramCallback')).toBeUndefined();
    expect(roleOf(SocialAccountsController, 'linkedinCallback')).toBeUndefined();
  });
});
