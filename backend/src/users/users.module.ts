import { Module } from '@nestjs/common';

import { AccountDataService } from './account-data.service';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  controllers: [UsersController],
  providers: [UsersService, AccountDataService],
  exports: [UsersService],
})
export class UsersModule {}
