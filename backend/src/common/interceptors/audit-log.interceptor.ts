import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Observable } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

import { PrismaService } from '../../prisma/prisma.service';

const MUTATING_METHODS = new Set(['POST', 'PATCH', 'PUT', 'DELETE']);

interface AuthedRequest extends Request {
  user?: { userId: string; email: string; orgId: string };
}

/**
 * Records every authenticated MUTATING request in AuditLog (Milestone 15.2).
 *
 * A single GLOBAL interceptor rather than decorating each controller: it
 * cannot be forgotten on a new route, and it captures the actor/target/
 * outcome uniformly — which is exactly what makes the audit trail complete.
 * It self-filters to POST/PATCH/PUT/DELETE with a `req.user`, so reads,
 * pre-auth routes (login/register/SSO callback), and health checks write
 * nothing.
 *
 * Both successes and failures are logged (with their status code), so a
 * denied attempt — a permission failure, a 422 — is on the record too, not
 * just the actions that went through. The write is fire-and-forget and its
 * own failure is swallowed: auditing must never break, or delay, the request
 * it is observing.
 */
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AuditLogInterceptor.name);

  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const res = context.switchToHttp().getResponse<Response>();

    const shouldAudit = MUTATING_METHODS.has(req.method) && !!req.user;
    if (!shouldAudit) {
      return next.handle();
    }

    return next.handle().pipe(
      tap(() => this.record(req, res.statusCode)),
      catchError((error: unknown) => {
        const status =
          typeof (error as { status?: number })?.status === 'number'
            ? (error as { status: number }).status
            : 500;
        this.record(req, status);
        throw error;
      }),
    );
  }

  private record(req: AuthedRequest, statusCode: number): void {
    const user = req.user!;
    const params = (req.params ?? {}) as Record<string, string>;
    // Best-effort target: the primary id param the route carries.
    const targetId =
      params.id ?? params.assetId ?? params.userId ?? params.inviteId ?? params.orgId ?? null;

    void this.prisma.auditLog
      .create({
        data: {
          orgId: user.orgId,
          actorId: user.userId,
          actorEmail: user.email,
          method: req.method,
          // Express sets `route.path` to the matched route pattern.
          path: (req as { route?: { path?: string } }).route?.path ?? req.path,
          targetId,
          statusCode,
        },
      })
      .catch((error: unknown) => {
        this.logger.warn(
          `Failed to write audit log: ${error instanceof Error ? error.message : String(error)}`,
        );
      });
  }
}
