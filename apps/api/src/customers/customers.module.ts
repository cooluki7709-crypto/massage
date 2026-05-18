import { Module } from '@nestjs/common';
import { EarningsModule } from '../earnings/earnings.module';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';

@Module({
  imports: [EarningsModule],
  controllers: [CustomersController],
  providers: [CustomersService],
})
export class CustomersModule {}
