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

  externalReadiness() {
    const checks = [
      this.externalGroup('Supabase Auth', 'supabase', [
        { key: 'SUPABASE_URL', validator: 'https-url' },
        { key: 'SUPABASE_ANON_KEY' },
        { key: 'SUPABASE_JWT_SECRET', validator: 'secret' },
      ]),
      this.externalGroup('Maps and geocoding', 'maps', [
        { key: 'MAPTILER_API_KEY' },
        { key: 'GEOAPIFY_API_KEY' },
      ]),
      this.externalGroup('MoMo payments', 'payments', [
        { key: 'MOMO_PARTNER_CODE' },
        { key: 'MOMO_ACCESS_KEY' },
        { key: 'MOMO_SECRET_KEY', validator: 'secret' },
      ]),
      this.externalGroup('VNPay payments', 'payments', [
        { key: 'VNPAY_TMN_CODE' },
        { key: 'VNPAY_HASH_SECRET', validator: 'secret' },
      ]),
      this.storageExternalReadiness(),
      this.externalGroup('Production SMS', 'sms', [
        { key: 'SMS_PROVIDER' },
        { key: 'SMS_API_URL' },
        { key: 'SMS_API_KEY', validator: 'secret' },
      ]),
      {
        name: 'OS push provider',
        category: 'push',
        status: 'BLOCKED',
        missing: ['ONESIGNAL_APP_ID or equivalent provider configuration'],
        configured: [],
        detail: 'Current delivery is intentionally in-app only until a production push provider is chosen.',
      },
    ];

    return {
      ok: checks.every((check) => check.status === 'READY'),
      timestamp: new Date().toISOString(),
      checks,
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

  private storageExternalReadiness() {
    const storage = this.storageStatus();
    const configured = ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY'].filter((key) =>
      this.config.get<string>(key),
    );
    if (this.config.get<string>('S3_REGION')) {
      configured.push('S3_REGION');
    }
    if (this.config.get<string>('S3_PUBLIC_BASE_URL')) {
      configured.push('S3_PUBLIC_BASE_URL');
    }

    return {
      name: 'File storage and CDN',
      category: 'storage',
      status: storage.ok ? 'READY' : configured.length > 0 ? 'PARTIAL' : 'BLOCKED',
      configured,
      missing: storage.missing,
      invalid: [],
      detail: storage.ok
        ? `${storage.provider} storage is configured for file upload/read flows.`
        : 'Configure S3-compatible, Supabase Storage S3, R2, or MinIO storage values.',
    };
  }

  private externalGroup(
    name: string,
    category: string,
    requirements: Array<{ key: string; validator?: 'https-url' | 'secret' }>,
  ) {
    const configured: string[] = [];
    const missing: string[] = [];
    const invalid: string[] = [];

    for (const requirement of requirements) {
      const value = this.config.get<string>(requirement.key)?.trim() ?? '';
      if (!value) {
        missing.push(requirement.key);
        continue;
      }

      if (requirement.validator === 'https-url' && !isHttpsUrl(value)) {
        invalid.push(requirement.key);
        continue;
      }

      if (requirement.validator === 'secret' && !isSecretLikeValue(value)) {
        invalid.push(requirement.key);
        continue;
      }

      configured.push(requirement.key);
    }

    const status =
      missing.length === 0 && invalid.length === 0 ? 'READY' : configured.length > 0 ? 'PARTIAL' : 'BLOCKED';

    return {
      name,
      category,
      status,
      configured,
      missing,
      invalid,
      detail:
        status === 'READY'
          ? 'All required environment values are configured.'
          : 'Set the missing or invalid environment values before production-like E2E testing.',
    };
  }
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error);
}

function isHttpsUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:';
  } catch {
    return false;
  }
}

function isSecretLikeValue(value: string) {
  return value.length >= 16 && !/^change-me$/i.test(value);
}
