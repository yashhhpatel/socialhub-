import { Module } from '@nestjs/common';

import { TokenEncryptionService } from '../common/crypto/token-encryption.service';
import { IngestionCron } from './ingestion/ingestion.cron';
import { IngestionService } from './ingestion/ingestion.service';
import { MetricFetcher } from './ingestion/metric-fetcher';

/**
 * Analytics (Phase 10). Milestone 10.1 wires the ingestion side — a
 * scheduled pull that normalizes each published post's platform metrics
 * into PostMetric rows. The query side (GraphQL + REST overview, 10.3) and
 * the dashboard (10.4) build on top of what this populates.
 *
 * TokenEncryptionService is provided directly (it's stateless) so ingestion
 * can decrypt stored account tokens without importing another module.
 */
@Module({
  providers: [IngestionService, MetricFetcher, IngestionCron, TokenEncryptionService],
  exports: [IngestionService],
})
export class AnalyticsModule {}
