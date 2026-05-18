import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Prisma } from '@prisma/client';
import { Job } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { FcmPushService } from './fcm-push.service';

type NotificationSendJob = {
  notificationId: string;
};

@Processor('notification-retry')
export class NotificationRetryProcessor extends WorkerHost {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FcmPushService,
  ) {
    super();
  }

  async process(job: Job<NotificationSendJob>) {
    const notification = await this.prisma.notification.findUnique({
      where: { id: job.data.notificationId },
      include: { user: { include: { pushDevices: { where: { enabled: true } } } } },
    });

    if (!notification) {
      return { skipped: true };
    }

    const devices = notification.user.pushDevices;
    if (devices.length === 0) {
      return { skipped: true, reason: 'NO_ENABLED_DEVICES', notificationId: notification.id };
    }

    const results = [];
    const data = toStringData(notification.data);

    for (const device of devices) {
      const result = await this.fcm.send({
        token: device.token,
        title: notification.title,
        body: notification.body,
        data,
      });

      await this.prisma.notificationDelivery.create({
        data: {
          notificationId: notification.id,
          pushDeviceId: device.id,
          provider: result.provider,
          status: result.status,
          response: toJson(result.response),
        },
      });

      results.push({ deviceId: device.id, status: result.status, provider: result.provider });
    }

    return {
      notificationId: notification.id,
      userId: notification.userId,
      results,
    };
  }
}

function toJson(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}

function toStringData(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return undefined;
  }

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>).map(([key, entry]) => [key, String(entry)]),
  );
}
