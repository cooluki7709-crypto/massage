import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  BookingStatus,
  ParticipantStatus,
  PaymentMethod,
  PaymentStatus,
  Prisma,
  ProviderStatus,
} from '@prisma/client';
import { EarningsService } from '../earnings/earnings.service';
import { MatchingGateway } from '../matching/matching.gateway';
import { MatchingService } from '../matching/matching.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly matching: MatchingService,
    private readonly matchingGateway: MatchingGateway,
    private readonly payments: PaymentsService,
    private readonly notifications: NotificationsService,
    private readonly earnings: EarningsService,
  ) {}

  async createOpenMatchingBooking(
    userId: string | undefined,
    input: {
      serviceId: string;
      scheduledStartAt: string;
      address: Prisma.InputJsonValue;
      lat: number;
      lng: number;
      notes?: string;
      paymentMethod: PaymentMethod;
    },
  ) {
    if (!userId) {
      throw new BadRequestException('Authenticated customer is required');
    }

    const customer = await this.prisma.customerProfile.findUnique({ where: { userId } });
    if (!customer) {
      throw new NotFoundException('Customer profile not found');
    }

    const service = await this.prisma.massageService.findUniqueOrThrow({ where: { id: input.serviceId } });
    const scheduledStartAt = new Date(input.scheduledStartAt);
    const scheduledEndAt = new Date(scheduledStartAt.getTime() + service.durationMin * 60_000);
    const expiresAt = new Date(Date.now() + 15 * 60_000);

    let booking = await this.prisma.booking.create({
      data: {
        customerProfileId: customer.id,
        status: BookingStatus.OPEN_MATCHING,
        scheduledStartAt,
        scheduledEndAt,
        address: input.address,
        lat: input.lat,
        lng: input.lng,
        notes: input.notes,
        openedAt: new Date(),
        expiresAt,
        services: {
          create: {
            serviceId: service.id,
            price: service.basePrice,
          },
        },
        payment: {
          create: this.payments.buildAuthorization(input.paymentMethod, service.basePrice),
        },
      },
      include: { services: { include: { service: true } }, payment: true, participants: true },
    });

    if (booking.payment?.id) {
      const payment = await this.payments.refreshAuthorizationForBooking(booking.payment.id, booking.id);
      booking = { ...booking, payment };
    }

    const result = this.matching.openBooking({ booking });
    if (booking.payment?.id) {
      await this.payments.scheduleStatusCheck(booking.payment.id);
    }
    await this.matching.registerActiveBooking(booking.id, result);
    await this.matching.scheduleBookingTimeout(booking.id, booking.expiresAt ?? expiresAt);
    await this.notifications.create({
      userId,
      type: 'booking.opened',
      title: 'Booking opened',
      body: 'We are looking for nearby providers.',
      data: { bookingId: booking.id },
    });
    this.matchingGateway.emitBookingOpened(booking.id, result);
    return result;
  }

  getBooking(id: string) {
    return this.prisma.booking.findUniqueOrThrow({
      where: { id },
      include: {
        services: { include: { service: true } },
        participants: { include: { providerProfile: true } },
        payment: true,
        chatRoom: true,
      },
    });
  }

  async getCustomerBooking(id: string, customerUserId: string) {
    const customer = await this.prisma.customerProfile.findUniqueOrThrow({ where: { userId: customerUserId } });
    return this.prisma.booking.findFirstOrThrow({
      where: { id, customerProfileId: customer.id },
      include: {
        services: { include: { service: true } },
        participants: { include: { providerProfile: true } },
        payment: true,
        chatRoom: true,
      },
    });
  }

  async listCustomerBookings(customerUserId: string) {
    const customer = await this.prisma.customerProfile.findUniqueOrThrow({ where: { userId: customerUserId } });
    return this.prisma.booking.findMany({
      where: { customerProfileId: customer.id },
      include: {
        services: { include: { service: true } },
        participants: { include: { providerProfile: true } },
        selectedProvider: true,
        payment: true,
        chatRoom: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  getOpenBookings() {
    return this.prisma.booking.findMany({
      where: { status: BookingStatus.OPEN_MATCHING, expiresAt: { gt: new Date() } },
      include: { services: { include: { service: true } }, participants: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listProviderBookings(providerUserId: string) {
    const provider = await this.requireProvider(providerUserId);
    return this.prisma.booking.findMany({
      where: {
        OR: [
          { selectedProviderId: provider.id },
          { participants: { some: { providerProfileId: provider.id } } },
        ],
      },
      include: {
        services: { include: { service: true } },
        participants: true,
        selectedProvider: true,
        payment: true,
        chatRoom: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  async joinBooking(bookingId: string, providerUserId: string | undefined) {
    const provider = await this.requireProvider(providerUserId);
    const booking = await this.prisma.booking.findUniqueOrThrow({ where: { id: bookingId } });
    if (booking.status !== BookingStatus.OPEN_MATCHING) {
      throw new BadRequestException('Booking is not open for matching');
    }

    const participant = await this.prisma.bookingParticipant.upsert({
      where: { bookingId_providerProfileId: { bookingId, providerProfileId: provider.id } },
      update: { status: ParticipantStatus.JOINED, respondedAt: new Date() },
      create: {
        bookingId,
        providerProfileId: provider.id,
        status: ParticipantStatus.JOINED,
        providerStatusAtJoin: provider.status,
      },
      include: { providerProfile: true },
    });

    await this.matching.registerParticipant(bookingId, provider.id);
    const result = this.matching.joinBooking(bookingId, participant);
    const customerUserId = await this.getCustomerUserIdForBooking(bookingId);
    await this.notifications.create({
      userId: customerUserId,
      type: 'provider.joined',
      title: 'A provider joined',
      body: `${provider.displayName} joined your booking.`,
      data: { bookingId, providerProfileId: provider.id },
    });
    this.matchingGateway.emitProviderJoined(bookingId, result);
    return result;
  }

  async selectProvider(bookingId: string, customerUserId: string, providerId: string) {
    const customer = await this.prisma.customerProfile.findUniqueOrThrow({ where: { userId: customerUserId } });
    const ownedBooking = await this.prisma.booking.findFirst({
      where: { id: bookingId, customerProfileId: customer.id, status: BookingStatus.OPEN_MATCHING },
    });
    if (!ownedBooking) {
      throw new BadRequestException('Booking is not open or does not belong to this customer');
    }

    const participant = await this.prisma.bookingParticipant.findUnique({
      where: { bookingId_providerProfileId: { bookingId, providerProfileId: providerId } },
    });
    if (!participant || participant.status === ParticipantStatus.REJECTED) {
      throw new BadRequestException('Provider must join before customer selection');
    }

    const booking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.MATCHED,
        selectedProviderId: providerId,
        participants: {
          update: {
            where: { bookingId_providerProfileId: { bookingId, providerProfileId: providerId } },
            data: { status: ParticipantStatus.SELECTED, respondedAt: new Date() },
          },
        },
        chatRoom: { create: {} },
      },
      include: { chatRoom: true, selectedProvider: true, payment: true },
    });

    await this.matching.closeBooking(bookingId);
    const result = this.matching.selectFinalProvider(bookingId, booking);
    if (booking.selectedProvider?.userId) {
      await this.notifications.create({
        userId: booking.selectedProvider.userId,
        type: 'booking.matched',
        title: 'You were selected',
        body: 'The customer selected you for this booking.',
        data: { bookingId },
      });
    }
    await this.notifications.create({
      userId: customerUserId,
      type: 'booking.matched',
      title: 'Provider selected',
      body: 'Your chat room is ready.',
      data: { bookingId, chatRoomId: booking.chatRoom?.id },
    });
    this.matchingGateway.emitBookingMatched(bookingId, result);
    return result;
  }

  async updateParticipant(bookingId: string, providerUserId: string | undefined, status: ParticipantStatus) {
    const provider = await this.requireProvider(providerUserId);
    return this.prisma.bookingParticipant.update({
      where: { bookingId_providerProfileId: { bookingId, providerProfileId: provider.id } },
      data: { status, respondedAt: new Date() },
    });
  }

  updateStatus(bookingId: string, status: BookingStatus) {
    return this.prisma.booking.update({ where: { id: bookingId }, data: { status } });
  }

  async updateProviderBookingStatus(bookingId: string, providerUserId: string, status: BookingStatus) {
    const provider = await this.requireProvider(providerUserId);
    await this.requireSelectedProvider(bookingId, provider.id);
    return this.updateStatus(bookingId, status);
  }

  async complete(bookingId: string, providerUserId: string) {
    const provider = await this.requireProvider(providerUserId);
    await this.requireSelectedProvider(bookingId, provider.id);

    const booking = await this.prisma.booking.update({
      where: { id: bookingId },
      data: {
        status: BookingStatus.COMPLETED,
        payment: { update: { status: PaymentStatus.CAPTURED } },
      },
      include: { payment: true, selectedProvider: true },
    });
    await this.earnings.createForCompletedBooking(bookingId, provider.id);
    const result = this.matching.completeBooking(bookingId, booking);
    const customerUserId = await this.getCustomerUserIdForBooking(bookingId);
    await this.notifications.create({
      userId: customerUserId,
      type: 'service.completed',
      title: 'Service completed',
      body: 'Please leave a review when you are ready.',
      data: { bookingId },
    });
    if (booking.selectedProvider?.userId) {
      await this.notifications.create({
        userId: booking.selectedProvider.userId,
        type: 'earning.created',
        title: 'Earning created',
        body: 'Your completed service has been added to earnings.',
        data: { bookingId },
      });
    }
    this.matchingGateway.emitServiceCompleted(bookingId, result);
    return result;
  }

  private async requireProvider(userId?: string) {
    if (!userId) {
      throw new BadRequestException('Authenticated provider is required');
    }

    const provider = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    if (provider.status === ProviderStatus.OFFLINE) {
      throw new BadRequestException('Provider must be online before joining bookings');
    }
    return provider;
  }

  private async requireSelectedProvider(bookingId: string, providerId: string) {
    const booking = await this.prisma.booking.findUniqueOrThrow({ where: { id: bookingId } });
    if (booking.selectedProviderId !== providerId) {
      throw new BadRequestException('Provider is not selected for this booking');
    }
    return booking;
  }

  private async getCustomerUserIdForBooking(bookingId: string) {
    const booking = await this.prisma.booking.findUniqueOrThrow({
      where: { id: bookingId },
      include: { customerProfile: true },
    });
    return booking.customerProfile.userId;
  }
}
