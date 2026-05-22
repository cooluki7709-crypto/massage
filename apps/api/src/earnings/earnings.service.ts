import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, EarningStatus, PayoutBatchStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const DEFAULT_PLATFORM_FEE_RATE = 0.2;

@Injectable()
export class EarningsService {
  constructor(private readonly prisma: PrismaService) {}

  async createForCompletedBooking(bookingId: string, providerProfileId: string) {
    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: {
        services: true,
        payment: true,
        review: true,
      },
    });

    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException('Earnings can be created only for completed bookings');
    }
    if (booking.selectedProviderId !== providerProfileId) {
      throw new BadRequestException('Provider is not selected for this booking');
    }

    const grossAmount =
      booking.payment?.amount ??
      booking.services.reduce((total, service) => total + service.price * service.quantity, 0);
    const tipAmount = booking.review?.tipAmount ?? 0;
    const platformFee = Math.round(grossAmount * DEFAULT_PLATFORM_FEE_RATE);
    const netAmount = grossAmount - platformFee + tipAmount;
    const availableAt = new Date(Date.now() + 24 * 60 * 60_000);

    return this.prisma.providerEarning.upsert({
      where: { bookingId },
      update: {
        providerProfileId,
        grossAmount,
        platformFee,
        tipAmount,
        netAmount,
        currency: booking.payment?.currency ?? 'VND',
        status: EarningStatus.PENDING,
        availableAt,
      },
      create: {
        bookingId,
        providerProfileId,
        grossAmount,
        platformFee,
        tipAmount,
        netAmount,
        currency: booking.payment?.currency ?? 'VND',
        status: EarningStatus.PENDING,
        availableAt,
      },
    });
  }

  async applyTip(bookingId: string, tipAmount: number) {
    if (tipAmount <= 0) {
      return null;
    }

    const earning = await this.prisma.providerEarning.findUnique({ where: { bookingId } });
    if (!earning) {
      return null;
    }

    return this.prisma.providerEarning.update({
      where: { bookingId },
      data: {
        tipAmount,
        netAmount: earning.grossAmount - earning.platformFee + tipAmount,
      },
    });
  }

  async listForProviderUser(userId: string) {
    const provider = await this.requireProviderProfile(userId);
    return this.prisma.providerEarning.findMany({
      where: { providerProfileId: provider.id },
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        booking: {
          include: {
            services: { include: { service: true } },
            customerProfile: { include: { user: { select: { id: true, phone: true, fullName: true } } } },
          },
        },
      },
    });
  }

  async summaryForProviderUser(userId: string) {
    const provider = await this.requireProviderProfile(userId);
    return this.summaryWhere({ providerProfileId: provider.id });
  }

  listForAdmin() {
    return this.prisma.providerEarning.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        providerProfile: { include: { user: { select: { id: true, phone: true, fullName: true } } } },
        booking: { include: { payment: true, review: true } },
      },
    });
  }

  adminSummary() {
    return this.summaryWhere({});
  }

  async markPaid(earningId: string) {
    const earning = await this.prisma.providerEarning.findUnique({ where: { id: earningId } });
    if (!earning) {
      throw new NotFoundException('Earning not found');
    }

    return this.prisma.providerEarning.update({
      where: { id: earningId },
      data: {
        status: EarningStatus.PAID,
        paidAt: new Date(),
      },
    });
  }

  async createProviderPayoutBatch(input: {
    providerProfileId: string;
    transferRef?: string;
    notes?: string;
  }) {
    const provider = await this.prisma.providerProfile.findUnique({ where: { id: input.providerProfileId } });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }

    return this.prisma.$transaction(async (tx) => {
      const earnings = await tx.providerEarning.findMany({
        where: {
          providerProfileId: input.providerProfileId,
          payoutBatchId: null,
          status: { in: [EarningStatus.PENDING, EarningStatus.AVAILABLE] },
          netAmount: { gt: 0 },
        },
        orderBy: { createdAt: 'asc' },
      });

      if (earnings.length === 0) {
        throw new BadRequestException('No unpaid earnings are eligible for payout');
      }

      const totalNetAmount = earnings.reduce((sum, earning) => sum + earning.netAmount, 0);
      const batch = await tx.providerPayoutBatch.create({
        data: {
          providerProfileId: input.providerProfileId,
          totalNetAmount,
          currency: earnings[0]?.currency ?? 'VND',
          status: PayoutBatchStatus.DRAFT,
          transferRef: input.transferRef ? normalizeNullable(input.transferRef) : null,
          notes: input.notes ? normalizeNullable(input.notes) : null,
        },
      });

      await tx.providerEarning.updateMany({
        where: { id: { in: earnings.map((earning) => earning.id) } },
        data: {
          payoutBatchId: batch.id,
        },
      });

      return tx.providerPayoutBatch.findUniqueOrThrow({
        where: { id: batch.id },
        include: {
          providerProfile: { include: { user: { select: { id: true, phone: true, fullName: true } } } },
          earnings: { orderBy: { createdAt: 'desc' } },
        },
      });
    });
  }

  listPayoutBatchesForAdmin() {
    return this.prisma.providerPayoutBatch.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        providerProfile: { include: { user: { select: { id: true, phone: true, fullName: true } } } },
        earnings: { orderBy: { createdAt: 'desc' } },
      },
    });
  }

  async updatePayoutBatch(
    payoutBatchId: string,
    input: { status?: PayoutBatchStatus; transferRef?: string | null; notes?: string | null },
  ) {
    const existing = await this.prisma.providerPayoutBatch.findUnique({
      where: { id: payoutBatchId },
      include: { earnings: true },
    });
    if (!existing) {
      throw new NotFoundException('Payout batch not found');
    }

    const nextStatus = input.status;
    if (nextStatus && !Object.values(PayoutBatchStatus).includes(nextStatus)) {
      throw new BadRequestException('Invalid payout batch status');
    }
    if (existing.status === PayoutBatchStatus.PAID && nextStatus && nextStatus !== PayoutBatchStatus.PAID) {
      throw new BadRequestException('Paid payout batches cannot be moved back to an unpaid status');
    }

    return this.prisma.$transaction(async (tx) => {
      const paidAt = nextStatus === PayoutBatchStatus.PAID ? (existing.paidAt ?? new Date()) : undefined;
      const batch = await tx.providerPayoutBatch.update({
        where: { id: payoutBatchId },
        data: {
          status: nextStatus,
          transferRef: input.transferRef === undefined ? undefined : normalizeNullable(input.transferRef),
          notes: input.notes === undefined ? undefined : normalizeNullable(input.notes),
          paidAt,
        },
      });

      if (nextStatus === PayoutBatchStatus.PAID) {
        await tx.providerEarning.updateMany({
          where: {
            payoutBatchId,
            status: { not: EarningStatus.CANCELLED },
          },
          data: {
            status: EarningStatus.PAID,
            paidAt: batch.paidAt,
          },
        });
      }

      return tx.providerPayoutBatch.findUniqueOrThrow({
        where: { id: payoutBatchId },
        include: {
          providerProfile: { include: { user: { select: { id: true, phone: true, fullName: true } } } },
          earnings: { orderBy: { createdAt: 'desc' } },
        },
      });
    });
  }

  async listPayoutBatchesForProviderUser(userId: string) {
    const provider = await this.requireProviderProfile(userId);
    return this.prisma.providerPayoutBatch.findMany({
      where: { providerProfileId: provider.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { earnings: { orderBy: { createdAt: 'desc' } } },
    });
  }

  async cancelForRefund(bookingId: string) {
    const earning = await this.prisma.providerEarning.findUnique({ where: { bookingId } });
    if (!earning) {
      return { skipped: true, reason: 'NO_EARNING' };
    }
    if (earning.status === EarningStatus.PAID) {
      return { skipped: true, reason: 'ALREADY_PAID', earningId: earning.id };
    }

    const cancelled = await this.prisma.providerEarning.update({
      where: { bookingId },
      data: {
        status: EarningStatus.CANCELLED,
        netAmount: 0,
      },
    });

    return { skipped: false, earning: cancelled };
  }

  private async summaryWhere(where: Prisma.ProviderEarningWhereInput) {
    const [total, pending, available, paid, count] = await Promise.all([
      this.prisma.providerEarning.aggregate({
        where,
        _sum: { grossAmount: true, platformFee: true, tipAmount: true, netAmount: true },
      }),
      this.prisma.providerEarning.aggregate({
        where: { ...where, status: EarningStatus.PENDING },
        _sum: { netAmount: true },
      }),
      this.prisma.providerEarning.aggregate({
        where: { ...where, status: EarningStatus.AVAILABLE },
        _sum: { netAmount: true },
      }),
      this.prisma.providerEarning.aggregate({
        where: { ...where, status: EarningStatus.PAID },
        _sum: { netAmount: true },
      }),
      this.prisma.providerEarning.count({ where }),
    ]);

    return {
      count,
      grossAmount: total._sum.grossAmount ?? 0,
      platformFee: total._sum.platformFee ?? 0,
      tipAmount: total._sum.tipAmount ?? 0,
      netAmount: total._sum.netAmount ?? 0,
      pendingNetAmount: pending._sum.netAmount ?? 0,
      availableNetAmount: available._sum.netAmount ?? 0,
      paidNetAmount: paid._sum.netAmount ?? 0,
      currency: 'VND',
    };
  }

  private async requireProviderProfile(userId: string) {
    const provider = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return provider;
  }
}

function normalizeNullable(value: string | null) {
  if (value === null) {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
