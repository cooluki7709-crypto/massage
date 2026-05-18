import { InjectQueue } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { BookingStatus, PaymentMethod, PaymentStatus, Prisma } from '@prisma/client';
import { Queue } from 'bullmq';
import { AdminService } from '../admin/admin.service';
import { EarningsService } from '../earnings/earnings.service';
import { PrismaService } from '../prisma/prisma.service';
import { CashPaymentAdapter, MomoPaymentAdapter, VnpayPaymentAdapter } from './adapters';
import { PaymentAdapter } from './payment-adapter';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly admin: AdminService,
    private readonly earnings: EarningsService,
    private readonly momo: MomoPaymentAdapter,
    private readonly vnpay: VnpayPaymentAdapter,
    private readonly cash: CashPaymentAdapter,
    @InjectQueue('payment-status-check') private readonly paymentStatusQueue: Queue,
  ) {}

  buildAuthorization(method: PaymentMethod, amount: number, bookingId = 'pending-booking') {
    const authorization = this.adapterFor(method).authorize({ bookingId, amount, currency: 'VND' });
    return {
      method: authorization.method,
      amount,
      status: authorization.status,
      providerRef: authorization.providerRef,
      rawMeta: toJsonOrUndefined(authorization.rawMeta),
    };
  }

  async scheduleStatusCheck(paymentId: string) {
    await this.paymentStatusQueue.add(
      'payment-status-check',
      { paymentId },
      {
        delay: 30_000,
        attempts: 5,
        backoff: { type: 'exponential', delay: 10_000 },
        removeOnComplete: true,
        removeOnFail: false,
      },
    );
  }

  async refreshAuthorizationForBooking(paymentId: string, bookingId: string) {
    const payment = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    const authorization = this.adapterFor(payment.method).authorize({
      bookingId,
      amount: payment.amount,
      currency: payment.currency,
    });

    return this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: authorization.status,
        providerRef: authorization.providerRef,
        rawMeta: toJsonOrUndefined(authorization.rawMeta),
      },
    });
  }

  async handleCallback(method: PaymentMethod, payload: unknown) {
    const parsed = this.adapterFor(method).parseCallback(payload);
    const payment = await this.prisma.payment.update({
      where: { providerRef: parsed.providerRef },
      data: {
        status: parsed.status,
        rawMeta: toJsonOrUndefined(parsed.rawMeta),
      },
    });
    return { ok: true, payment };
  }

  async checkAndSyncStatus(paymentId: string) {
    const payment = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    if (!payment.providerRef) {
      return { skipped: true, reason: 'NO_PROVIDER_REF' };
    }

    const status = this.adapterFor(payment.method).checkStatus(payment.providerRef);
    const updated = await this.prisma.payment.update({
      where: { id: payment.id },
      data: { status },
    });

    return { paymentId, status: updated.status };
  }

  async release(paymentId: string) {
    const payment = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    const status = this.adapterFor(payment.method).release(payment.providerRef);
    return this.prisma.payment.update({
      where: { id: paymentId },
      data: { status },
    });
  }

  async refund(actorId: string, paymentId: string) {
    const existing = await this.prisma.payment.findUniqueOrThrow({ where: { id: paymentId } });
    const payment = await this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: PaymentStatus.REFUNDED,
        booking: { update: { status: BookingStatus.REFUNDED } },
        refunds: {
          create: {
            bookingId: existing.bookingId,
            amount: existing.amount,
            reason: 'Admin manual refund',
            status: 'REQUESTED',
          },
        },
      },
      include: { refunds: true },
    });
    const earningCancellation = await this.earnings.cancelForRefund(existing.bookingId);
    const earningCancellationAudit =
      earningCancellation.skipped || !('earning' in earningCancellation)
        ? { skipped: true, reason: earningCancellation.reason }
        : { skipped: false, earningId: earningCancellation.earning?.id ?? 'unknown' };

    await this.admin.writeAudit(actorId, 'payment.refund', `payment:${paymentId}`, {
      amount: payment.amount,
      method: payment.method,
      earningCancellation: earningCancellationAudit,
    });

    return payment;
  }

  private adapterFor(method: PaymentMethod): PaymentAdapter {
    if (method === PaymentMethod.MOMO) {
      return this.momo;
    }
    if (method === PaymentMethod.VNPAY) {
      return this.vnpay;
    }
    return this.cash;
  }
}

function toJsonOrUndefined(value: unknown): Prisma.InputJsonValue | undefined {
  if (value === undefined) {
    return undefined;
  }
  return JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
}
