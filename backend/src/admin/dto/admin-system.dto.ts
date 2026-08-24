export class AdminHealthDto {
  db: boolean;
  redis: boolean;
  uptimeSeconds: number;
  /** Whether Sentry error monitoring is configured (SENTRY_DSN present). */
  sentryConfigured: boolean;
}

export class AdminQueueStatDto {
  name: string;
  waiting: number;
  active: number;
  completed: number;
  failed: number;
  delayed: number;
}

export class AdminRecentErrorDto {
  orgId: string;
  actorEmail: string;
  method: string;
  path: string;
  statusCode: number;
  createdAt: Date;
}
