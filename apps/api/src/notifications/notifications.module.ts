import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { FcmPushService } from './fcm-push.service';
import { NotificationsController } from './notifications.controller';
import { NotificationRetryProcessor } from './notifications.processor';
import { NotificationsService } from './notifications.service';

@Module({
  imports: [BullModule.registerQueue({ name: 'notification-retry' })],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationRetryProcessor, FcmPushService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
