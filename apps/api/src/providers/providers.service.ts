import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { FileVisibility, ProviderStatus, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RedisStateService } from '../redis/redis-state.service';

@Injectable()
export class ProvidersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redisState: RedisStateService,
  ) {}

  async findNearby(lat: number, lng: number) {
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new BadRequestException('lat and lng query params are required');
    }

    const providers = await this.prisma.providerProfile.findMany({
      where: {
        status: { in: [ProviderStatus.ONLINE_AVAILABLE, ProviderStatus.ONLINE_AVAILABLE_SOON] },
        currentLat: { not: null },
        currentLng: { not: null },
        verification: { status: VerificationStatus.APPROVED },
      },
      include: {
        user: { select: { fullName: true, phone: true } },
        services: { include: { service: true } },
        reviews: { select: { rating: true }, take: 20, orderBy: { createdAt: 'desc' } },
      },
      take: 50,
    });

    return providers
      .map((provider) => {
        const distanceMeters = roundTo100Meters(
          haversineMeters(lat, lng, Number(provider.currentLat), Number(provider.currentLng)),
        );
        return { ...provider, distanceMeters };
      })
      .sort((a, b) => a.distanceMeters - b.distanceMeters || a.status.localeCompare(b.status));
  }

  getDetail(id: string) {
    return this.prisma.providerProfile.findUniqueOrThrow({
      where: { id },
      include: {
        user: { select: { fullName: true } },
        verification: { select: { status: true } },
        services: { include: { service: true } },
        reviews: { take: 10, orderBy: { createdAt: 'desc' } },
      },
    });
  }

  async updateProfile(userId: string | undefined, input: { displayName?: string; bio?: string }) {
    const provider = await this.requireProvider(userId);
    return this.prisma.providerProfile.update({
      where: { id: provider.id },
      data: input,
    });
  }

  async setStatus(userId: string | undefined, status: ProviderStatus) {
    const provider = await this.requireProvider(userId);
    const updated = await this.prisma.providerProfile.update({
      where: { id: provider.id },
      data: { status },
    });
    await this.redisState.setProviderStatus(provider.id, status);
    return updated;
  }

  async updateLocation(userId: string | undefined, input: { lat: number; lng: number }) {
    const provider = await this.requireProvider(userId);
    const updated = await this.prisma.providerProfile.update({
      where: { id: provider.id },
      data: {
        currentLat: input.lat,
        currentLng: input.lng,
        locationSnapshots: { create: { lat: input.lat, lng: input.lng } },
      },
    });
    await this.redisState.setProviderLocation(provider.id, input);
    return { ...updated, locationUpdated: true };
  }

  async getVerification(userId: string | undefined) {
    const provider = await this.requireProvider(userId);
    return this.prisma.providerVerification.upsert({
      where: { providerProfileId: provider.id },
      update: {},
      create: { providerProfileId: provider.id },
      include: { files: { orderBy: { createdAt: 'desc' } } },
    });
  }

  async submitVerification(userId: string | undefined, input: { fileIds?: string[] }) {
    const provider = await this.requireProvider(userId);
    const verification = await this.prisma.providerVerification.upsert({
      where: { providerProfileId: provider.id },
      update: {
        status: VerificationStatus.SUBMITTED,
        submittedAt: new Date(),
        rejectionReason: null,
      },
      create: {
        providerProfileId: provider.id,
        status: VerificationStatus.SUBMITTED,
        submittedAt: new Date(),
      },
    });

    if (input.fileIds?.length) {
      await this.prisma.fileAsset.updateMany({
        where: {
          id: { in: input.fileIds },
          visibility: FileVisibility.PRIVATE,
        },
        data: { providerVerificationId: verification.id },
      });
    }

    return this.prisma.providerVerification.findUniqueOrThrow({
      where: { id: verification.id },
      include: { files: { orderBy: { createdAt: 'desc' } } },
    });
  }

  private async requireProvider(userId?: string) {
    if (!userId) {
      throw new BadRequestException('Authenticated provider is required');
    }

    const provider = await this.prisma.providerProfile.findUnique({ where: { userId } });
    if (!provider) {
      throw new NotFoundException('Provider profile not found');
    }
    return provider;
  }
}

function roundTo100Meters(value: number) {
  return Math.round(value / 100) * 100;
}

function haversineMeters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const earthRadius = 6371000;
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLng / 2) ** 2;
  return earthRadius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRadians(value: number) {
  return (value * Math.PI) / 180;
}
