import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ServicesService {
  constructor(private readonly prisma: PrismaService) {}

  listActive() {
    return this.prisma.massageService.findMany({
      where: { active: true },
      orderBy: [{ basePrice: 'asc' }, { name: 'asc' }],
    });
  }

  create(input: { name: string; description?: string; durationMin: number; basePrice: number }) {
    return this.prisma.massageService.create({ data: input });
  }
}

