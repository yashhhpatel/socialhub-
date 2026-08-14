import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsQueryService } from './analytics-query.service';
import { AnalyticsResolver } from './analytics.resolver';
import { IngestionCron } from './ingestion/ingestion.cron';
import { IngestionService } from './ingestion/ingestion.service';
import { MetricFetcher } from './ingestion/metric-fetcher';

/**
 * Analytics (Phase 10). 10.1/10.2 wire the ingestion side — a scheduled
 * pull that normalizes each published post's platform metrics into
 * PostMetric rows. 10.3 adds the read side: AnalyticsQueryService feeds both
 * a GraphQL resolver (dashboard's one-round-trip overview) and a REST
 * fallback controller, so the two never diverge.
 *
 * TokenEncryptionService is provided directly (it's stateless) so ingestion
 * can decrypt stored account tokens without importing another module. The
 * GraphQL driver itself is configured once at the app root (app.module).
 */
@Module({
  controllers: [AnalyticsController],
  providers: [
    IngestionService,
    MetricFetcher,
    IngestionCron,
    AnalyticsQueryService,
    AnalyticsResolver,
    TokenEncryptionService,
  ],
  exports: [IngestionService, AnalyticsQueryService],
})
export class AnalyticsModule {}
