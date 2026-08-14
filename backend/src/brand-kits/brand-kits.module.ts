import { Module } from '@nestjs/common';

import { BrandKitsController } from './brand-kits.controller';
import { BrandKitsService } from './brand-kits.service';

@Module({
  controllers: [BrandKitsController],
  providers: [BrandKitsService],
  exports: [BrandKitsService],
})
export class BrandKitsModule {}
