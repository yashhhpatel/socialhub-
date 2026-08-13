import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import * as Sentry from '@sentry/node';
import { randomUUID } from 'crypto';
import { Request, Response } from 'express';

/**
 * The one place every error becomes an HTTP response (Milestone 6.1).
 *
 * `@Catch()` with no argument catches EVERYTHING — both HttpExceptions the
 * app throws deliberately and anything unexpected (a bug, a driver error, a
 * thrown string). Without this, an unhandled non-HTTP error reaches Nest's
 * default handler, which in development leaks a stack trace to the client
 * and in any case produces a shape the frontend can't read.
 *
 * The envelope matches docs/SocialHub_REST_API_Design.md §0
 * (statusCode/error/message/requestId). Crucially it PRESERVES the existing
 * `message` field for HttpExceptions — a string for most, an array for
 * class-validator failures — because the frontend's describeApiError, and
 * every backend test asserting on error text, already depend on it. This
 * filter only ADDS fields (requestId, path, timestamp); it never reshapes
 * what was already there.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    // A correlation id the client can quote back — the join between a
    // user's "it broke, here's the id" and the matching server log line.
    const requestId = randomUUID();
    const meta = {
      requestId,
      path: request.url,
      timestamp: new Date().toISOString(),
    };

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const payload = exception.getResponse();

      // Nest's built-in exceptions return an object shaped exactly like the
      // envelope's core ({ statusCode, message, error }); a hand-thrown
      // `new HttpException('text', status)` returns a bare string. Normalise
      // the string case, pass the object case through untouched so the
      // `message` array from ValidationPipe survives.
      const body =
        typeof payload === 'string'
          ? { statusCode: status, message: payload, error: exception.name }
          : { statusCode: status, ...(payload as Record<string, unknown>) };

      response.status(status).json({ ...body, ...meta });
      return;
    }

    // Anything not an HttpException is, by definition, unplanned. Log the
    // real error (with its stack) server-side against the requestId, and
    // return a deliberately generic body — no internals ever cross the wire.
    this.logger.error(
      `Unhandled exception on ${request.method} ${request.url} [${requestId}]: ${
        exception instanceof Error ? exception.stack : String(exception)
      }`,
    );

    // Report to Sentry (Milestone 6.3). Only unplanned errors are sent —
    // expected HttpExceptions (4xx) are the app working as designed and
    // would just be noise. A no-op when SENTRY_DSN is unset; the requestId
    // is attached so a Sentry event and a log line can be joined.
    Sentry.captureException(exception, { tags: { requestId } });

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      error: 'Internal Server Error',
      message: 'An unexpected error occurred. Please try again.',
      ...meta,
    });
  }
}
