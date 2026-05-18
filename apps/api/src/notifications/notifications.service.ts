import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';

type CreateNotificationInput = {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: unknown;
};

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('notification-retry') private readonly notificationQueue: Queue,
  ) {}

  async create(input: CreateNotificationInput) {
    const notification = await this.prisma.notification.create({
      data: {
        userId: input.userId,
        type: input.type,
        title: input.title,
        body: input.body,
        data: input.data === undefined ? undefined : JSON.parse(JSON.stringify(input.data)),
      },
    });

    await this.notificationQueue.add(
      'notification-send',
      { notificationId: notification.id },
      {
        attempts: 3,
        backoff: { type: 'exponential', delay: 5_000 },
        removeOnComplete: true,
        removeOnFail: false,
      },
    );

    return notification;
  }

  listForUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  markRead(userId: string, notificationId: string) {
    return this.prisma.notification.update({
      where: { id: notificationId, userId },
      data: { readAt: new Date() },
    });
  }

  registerDeviceToken(userId: string, input: { token: string; platform: string }) {
    return this.prisma.pushDevice.upsert({
      where: { token: input.token },
      update: {
        userId,
        platform: input.platform,
        enabled: true,
      },
      create: {
        userId,
        token: input.token,
        platform: input.platform,
      },
    });
  }
}
