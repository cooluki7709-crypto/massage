import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  getMe(userId?: string) {
    if (!userId) {
      throw new BadRequestException('Authenticated user is required');
    }

    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: {
        customerProfile: true,
        providerProfile: {
          include: { verification: { include: { files: true } }, services: { include: { service: true } } },
        },
      },
    });
  }

  updateMe(userId: string | undefined, input: { fullName?: string; email?: string }) {
    if (!userId) {
      throw new BadRequestException('Authenticated user is required');
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName: input.fullName,
        email: input.email,
      },
    });
  }
}
