import { BadRequestException, Injectable } from '@nestjs/common';
import { BookingStatus, Prisma } from '@prisma/client';
import { EarningsService } from '../earnings/earnings.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly earnings: EarningsService,
  ) {}

  async createReview(
    userId: string | undefined,
    input: { bookingId: string; rating: number; comment?: string; tipAmount?: number },
  ) {
    if (!userId) {
      throw new BadRequestException('Authenticated customer is required');
    }

    const customer = await this.prisma.customerProfile.findUniqueOrThrow({ where: { userId } });
    const booking = await this.prisma.booking.findUniqueOrThrow({ where: { id: input.bookingId } });
    if (booking.customerProfileId !== customer.id) {
      throw new BadRequestException('Booking does not belong to this customer');
    }
    if (booking.status !== BookingStatus.COMPLETED) {
      throw new BadRequestException('Review is allowed only after service completion');
    }
    if (!booking.selectedProviderId) {
      throw new BadRequestException('Booking has no selected provider');
    }
    if (input.rating < 1 || input.rating > 5) {
      throw new BadRequestException('Rating must be between 1 and 5');
    }

    const review = await this.prisma.$transaction(async (tx) => {
      const review = await tx.review.create({
        data: {
          bookingId: booking.id,
          customerProfileId: customer.id,
          providerProfileId: booking.selectedProviderId!,
          rating: input.rating,
          comment: input.comment,
          tipAmount: input.tipAmount ?? 0,
        },
      });

      await recalculateProviderRating(tx, booking.selectedProviderId!);
      return review;
    });

    await this.earnings.applyTip(booking.id, input.tipAmount ?? 0);
    return review;
  }
}

async function recalculateProviderRating(tx: Prisma.TransactionClient, providerProfileId: string) {
  const aggregate = await tx.review.aggregate({
    where: { providerProfileId, status: 'PUBLISHED' },
    _avg: { rating: true },
    _count: { rating: true },
  });

  await tx.providerProfile.update({
    where: { id: providerProfileId },
    data: {
      ratingAvg: aggregate._avg.rating ?? 0,
      reviewCount: aggregate._count.rating,
    },
  });
}
