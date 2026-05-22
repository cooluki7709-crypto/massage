import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { RedisStateService } from '../redis/redis-state.service';

@Injectable()
export class HealthService {
  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly redis: RedisStateService,
  ) {}

  healthcheck() {
    return {
      ok: true,
      service: 'massage-vn-api',
      timestamp: new Date().toISOString(),
      environment: this.config.get<string>('NODE_ENV') ?? 'development',
    };
  }

  async readiness() {
    const [database, redis] = await Promise.all([this.databaseStatus(), this.redisStatus()]);
    const storage = this.storageStatus();
    const ok = database.ok && redis.ok;

    return {
      ok,
      timestamp: new Date().toISOString(),
      checks: {
        database,
        redis,
        storage,
      },
    };
  }

  private async databaseStatus() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { ok: true };
    } catch (error) {
      return { ok: false, error: errorMessage(error) };
    }
  }

  private async redisStatus() {
    try {
      const pong = await this.redis.ping();
      return { ok: pong === 'PONG', response: pong };
    } catch (error) {
      return { ok: false, error: errorMessage(error) };
    }
  }

  private storageStatus() {
    const required = ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY'];
    const missing = required.filter((key) => !this.config.get<string>(key));
    const provider = this.config.get<string>('STORAGE_PROVIDER')?.trim() || 's3-compatible';
    const mode =
      missing.length > 0
        ? 'placeholder'
        : provider === 'supabase-storage-s3'
          ? 'supabase-storage-s3'
          : 's3-compatible-presigned';

    return {
      ok: missing.length === 0,
      provider,
      mode,
      missing,
      publicBaseUrlConfigured: Boolean(this.config.get<string>('S3_PUBLIC_BASE_URL')),
    };
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}
