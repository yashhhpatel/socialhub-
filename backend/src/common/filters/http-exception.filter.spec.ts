import {
  ArgumentsHost,
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import * as Sentry from '@sentry/node';

import { AllExceptionsFilter } from './http-exception.filter';

describe('AllExceptionsFilter', () => {
  let filter: AllExceptionsFilter;
  let statusMock: jest.Mock;
  let jsonMock: jest.Mock;

  /** Captures the response body the filter writes for a given thrown value. */
  function run(exception: unknown, url = '/some/path', method = 'GET') {
    jsonMock = jest.fn();
    statusMock = jest.fn().mockReturnValue({ json: jsonMock });

    const host = {
      switchToHttp: () => ({
        getResponse: () => ({ status: statusMock }),
        getRequest: () => ({ url, method }),
      }),
    } as unknown as ArgumentsHost;

    filter.catch(exception, host);

    return {
      status: statusMock.mock.calls[0][0] as number,
      body: jsonMock.mock.calls[0][0] as Record<string, unknown>,
    };
  }

  let captureSpy: jest.SpyInstance;

  beforeEach(() => {
    filter = new AllExceptionsFilter();
    // The unhandled-error path logs a stack; keep test output clean.
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    // captureException is a no-op without a DSN, but assert on the intent
    // rather than the SDK's internal state.
    captureSpy = jest.spyOn(Sentry, 'captureException').mockReturnValue('evt');
  });

  afterEach(() => jest.restoreAllMocks());

  describe('HttpException passthrough', () => {
    it('preserves status, message, and error for a built-in exception', () => {
      const { status, body } = run(new ConflictException('Email already exists.'));

      expect(status).toBe(HttpStatus.CONFLICT);
      expect(body.statusCode).toBe(HttpStatus.CONFLICT);
      expect(body.message).toBe('Email already exists.');
      expect(body.error).toBe('Conflict');
    });

    it('preserves the ARRAY message class-validator produces', () => {
      // The frontend's describeApiError joins this array; it must survive
      // the filter unchanged, or multi-field validation errors break.
      const validation = new BadRequestException([
        'email must be an email',
        'password is too short',
      ]);

      const { body } = run(validation);

      expect(Array.isArray(body.message)).toBe(true);
      expect(body.message).toEqual([
        'email must be an email',
        'password is too short',
      ]);
    });

    it('normalises a bare-string HttpException into the envelope', () => {
      const { status, body } = run(
        new HttpException('Teapot.', HttpStatus.I_AM_A_TEAPOT),
      );

      expect(status).toBe(HttpStatus.I_AM_A_TEAPOT);
      expect(body.statusCode).toBe(HttpStatus.I_AM_A_TEAPOT);
      expect(body.message).toBe('Teapot.');
    });

    it('adds correlation metadata without dropping the core fields', () => {
      const { body } = run(new ConflictException('x'), '/auth/register', 'POST');

      expect(typeof body.requestId).toBe('string');
      expect((body.requestId as string).length).toBeGreaterThan(0);
      expect(body.path).toBe('/auth/register');
      expect(typeof body.timestamp).toBe('string');
    });
  });

  describe('unhandled exceptions', () => {
    it('returns a generic 500 that leaks nothing about the internal error', () => {
      const { status, body } = run(new Error('DB password is hunter2 at 10.0.0.5'));

      expect(status).toBe(HttpStatus.INTERNAL_SERVER_ERROR);
      expect(body.statusCode).toBe(HttpStatus.INTERNAL_SERVER_ERROR);
      expect(body.error).toBe('Internal Server Error');
      expect(body.message).toBe('An unexpected error occurred. Please try again.');
      // The sensitive detail must not appear anywhere in the response.
      expect(JSON.stringify(body)).not.toContain('hunter2');
      expect(JSON.stringify(body)).not.toContain('10.0.0.5');
    });

    it('handles a thrown non-Error value without itself throwing', () => {
      const { status, body } = run('a bare string was thrown');

      expect(status).toBe(HttpStatus.INTERNAL_SERVER_ERROR);
      expect(body.message).toBe('An unexpected error occurred. Please try again.');
    });

    it('logs the real error server-side against the request id', () => {
      const logSpy = jest.spyOn(Logger.prototype, 'error');
      const { body } = run(new Error('boom'), '/publish/now', 'POST');

      expect(logSpy).toHaveBeenCalledTimes(1);
      const logged = logSpy.mock.calls[0][0] as string;
      expect(logged).toContain('POST /publish/now');
      expect(logged).toContain(body.requestId as string);
      expect(logged).toContain('boom');
    });

    it('reports the error to Sentry, tagged with the request id', () => {
      const error = new Error('boom');
      const { body } = run(error);

      expect(captureSpy).toHaveBeenCalledTimes(1);
      expect(captureSpy).toHaveBeenCalledWith(error, {
        tags: { requestId: body.requestId },
      });
    });
  });

  describe('Sentry reporting scope', () => {
    it('does NOT report expected HttpExceptions — those are the app working', () => {
      // A 4xx is by design; sending it to Sentry would be pure noise.
      run(new ConflictException('dup'));
      run(new BadRequestException(['bad']));

      expect(captureSpy).not.toHaveBeenCalled();
    });
  });
});
