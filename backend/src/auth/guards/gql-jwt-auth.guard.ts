import { ExecutionContext, Injectable } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';
import { AuthGuard } from '@nestjs/passport';

/**
 * The 'jwt' Passport guard adapted for GraphQL (Milestone 10.3).
 *
 * Passport's AuthGuard reads the request from the HTTP execution context,
 * which is empty for a GraphQL resolver — the request lives in the GraphQL
 * context instead (populated by GraphQLModule's `context: ({ req }) =>
 * ({ req })`). Overriding getRequest to unwrap it is the standard way to
 * reuse the same JWT strategy for GraphQL. Kept separate from the HTTP
 * JwtAuthGuard so REST routes are untouched.
 */
@Injectable()
export class GqlJwtAuthGuard extends AuthGuard('jwt') {
  getRequest(context: ExecutionContext) {
    const gqlCtx = GqlExecutionContext.create(context);
    return gqlCtx.getContext().req;
  }
}
