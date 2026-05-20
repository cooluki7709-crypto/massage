import { Injectable } from '@nestjs/common';
import { Prisma, ReviewStatus, VerificationStatus } from '@prisma/client';
import { EarningsService } from '../earnings/earnings.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly earnings: EarningsService,
    private readonly notifications: NotificationsService,
  ) {}

  listUsers() {
    return this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { customerProfile: true, providerProfile: true },
    });
  }

  listProviders() {
    return this.prisma.providerProfile.findMany({
      orderBy: { id: 'desc' },
      include: {
        user: {
          include: {
            pushDevices: {
              orderBy: { createdAt: 'desc' },
              include: {
                deliveries: {
                  orderBy: { attemptedAt: 'desc' },
                  take: 1,
                },
              },
            },
          },
        },
        verification: { include: { files: true } },
        services: { include: { service: true } },
      },
    });
  }

  async enablePushDevice(actorId: string, pushDeviceId: string) {
    const device = await this.prisma.pushDevice.update({
      where: { id: pushDeviceId },
      data: { enabled: true },
    });

    await this.writeAudit(actorId, 'push_device.enable', `push_device:${pushDeviceId}`, {
      pushDeviceId,
      userId: device.userId,
      platform: device.platform,
    });

    return { ok: true, pushDeviceId: device.id };
  }

  async reviewProvider(actorId: string, providerProfileId: string, status: VerificationStatus, reason?: string) {
    const verification = await this.prisma.providerVerification.upsert({
      where: { providerProfileId },
      update: {
        status,
        rejectionReason: status === VerificationStatus.REJECTED ? reason : null,
        reviewedAt: new Date(),
      },
      create: {
        providerProfileId,
        status,
        rejectionReason: status === VerificationStatus.REJECTED ? reason : null,
        submittedAt: new Date(),
        reviewedAt: new Date(),
      },
    });

    await this.writeAudit(actorId, `provider.${status.toLowerCase()}`, `provider:${providerProfileId}`, {
      reason,
    });

    const provider = await this.prisma.providerProfile.findUnique({
      where: { id: providerProfileId },
      select: { userId: true },
    });
    if (provider) {
      await this.notifications.create({
        userId: provider.userId,
        type: `provider.verification.${status.toLowerCase()}`,
        title: status === VerificationStatus.APPROVED ? 'Verification approved' : 'Verification needs updates',
        body: status === VerificationStatus.APPROVED ? 'You can now receive matching jobs.' : reason ?? 'Please update your documents.',
        data: { providerProfileId, status, reason },
      });
    }

    return verification;
  }

  listBookings() {
    return this.prisma.booking.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        customerProfile: { include: { user: true } },
        selectedProvider: { include: { user: true } },
        participants: { include: { providerProfile: { include: { user: true } } } },
        services: { include: { service: true } },
        payment: true,
        chatRoom: true,
      },
    });
  }

  listPayments() {
    return this.prisma.payment.findMany({
      orderBy: { id: 'desc' },
      take: 100,
      include: {
        booking: { include: { customerProfile: { include: { user: true } }, selectedProvider: true } },
        refunds: true,
      },
    });
  }

  listRefunds() {
    return this.prisma.refund.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        payment: true,
        booking: { include: { customerProfile: { include: { user: true } }, selectedProvider: true } },
      },
    });
  }

  listEarnings() {
    return this.earnings.listForAdmin();
  }

  earningsSummary() {
    return this.earnings.adminSummary();
  }

  async markEarningPaid(actorId: string, earningId: string) {
    const earning = await this.earnings.markPaid(earningId);
    await this.writeAudit(actorId, 'earning.paid', `earning:${earning.id}`, {
      bookingId: earning.bookingId,
      providerProfileId: earning.providerProfileId,
      netAmount: earning.netAmount,
    });
    return earning;
  }

  listPayoutBatches() {
    return this.earnings.listPayoutBatchesForAdmin();
  }

  async createPayoutBatch(
    actorId: string,
    input: { providerProfileId: string; transferRef?: string; notes?: string },
  ) {
    const batch = await this.earnings.createProviderPayoutBatch(input);
    await this.writeAudit(actorId, 'payout_batch.create', `payout_batch:${batch.id}`, {
      providerProfileId: batch.providerProfileId,
      totalNetAmount: batch.totalNetAmount,
      transferRef: batch.transferRef,
      earningCount: batch.earnings.length,
    });
    return batch;
  }

  listReviews() {
    return this.prisma.review.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { booking: true, customerProfile: { include: { user: true } }, providerProfile: true },
    });
  }

  async moderateReview(actorId: string, reviewId: string, input: { status: ReviewStatus; reportReason?: string }) {
    return this.prisma.$transaction(async (tx) => {
      const review = await tx.review.update({
        where: { id: reviewId },
        data: {
          status: input.status,
          reportReason: input.reportReason,
          moderatedAt: new Date(),
        },
      });

      const aggregate = await tx.review.aggregate({
        where: { providerProfileId: review.providerProfileId, status: ReviewStatus.PUBLISHED },
        _avg: { rating: true },
        _count: { rating: true },
      });

      await tx.providerProfile.update({
        where: { id: review.providerProfileId },
        data: {
          ratingAvg: aggregate._avg.rating ?? 0,
          reviewCount: aggregate._count.rating,
        },
      });

      await tx.adminAuditLog.create({
        data: {
          actorId,
          action: 'review.moderate',
          target: `review:${review.id}`,
          metadata: toJson({ status: input.status, reportReason: input.reportReason }),
        },
      });

      return review;
    });
  }

  listCoupons() {
    return this.prisma.coupon.findMany({
      orderBy: { code: 'asc' },
      take: 100,
    });
  }

  async createCoupon(
    actorId: string,
    input: {
      code: string;
      description?: string;
      discount: unknown;
      active?: boolean;
      startsAt?: string;
      endsAt?: string;
    },
  ) {
    const coupon = await this.prisma.coupon.create({
      data: {
        code: input.code.trim().toUpperCase(),
        description: input.description,
        discount: toJson(input.discount),
        active: input.active ?? true,
        startsAt: input.startsAt ? new Date(input.startsAt) : undefined,
        endsAt: input.endsAt ? new Date(input.endsAt) : undefined,
      },
    });

    await this.writeAudit(actorId, 'coupon.create', `coupon:${coupon.id}`, { code: coupon.code });
    return coupon;
  }

  async updateCoupon(
    actorId: string,
    id: string,
    input: {
      description?: string;
      discount?: unknown;
      active?: boolean;
      startsAt?: string | null;
      endsAt?: string | null;
    },
  ) {
    const coupon = await this.prisma.coupon.update({
      where: { id },
      data: {
        description: input.description,
        discount: input.discount === undefined ? undefined : toJson(input.discount),
        active: input.active,
        startsAt: input.startsAt === undefined ? undefined : input.startsAt ? new Date(input.startsAt) : null,
        endsAt: input.endsAt === undefined ? undefined : input.endsAt ? new Date(input.endsAt) : null,
      },
    });

    await this.writeAudit(actorId, 'coupon.update', `coupon:${coupon.id}`, { active: coupon.active });
    return coupon;
  }

  listAuditLogs() {
    return this.prisma.adminAuditLog.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { actor: { select: { id: true, phone: true, fullName: true } } },
    });
  }

  listNotifications() {
    return this.prisma.notification.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        user: { select: { id: true, phone: true, fullName: true } },
        deliveries: { include: { pushDevice: true }, orderBy: { attemptedAt: 'desc' } },
      },
    });
  }

  async retryNotification(actorId: string, notificationId: string) {
    const result = await this.notifications.retry(notificationId);
    await this.writeAudit(actorId, 'notification.retry', `notification:${notificationId}`, {
      notificationId,
    });
    return result;
  }

  writeAudit(actorId: string, action: string, target: string, metadata?: Prisma.InputJsonValue) {
    return this.prisma.adminAuditLog.create({
      data: {
        actorId,
        action,
        target,
        metadata,
      },
    });
  }
}

function toJson(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}
