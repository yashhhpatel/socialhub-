import { Module } from '@nestjs/common';

import { MarketplaceController } from './marketplace.controller';
import { TemplatesController } from './templates.controller';
import { TemplatesService } from './templates.service';

/**
 * MarketplaceController is listed FIRST so its literal `GET
 * /templates/marketplace` route is registered before TemplatesController's
 * `GET /templates/:id`, which would otherwise match "marketplace" as an id.
 */
@Module({
  controllers: [MarketplaceController, TemplatesController],
  providers: [TemplatesService],
  exports: [TemplatesService],
})
export class TemplatesModule {}
