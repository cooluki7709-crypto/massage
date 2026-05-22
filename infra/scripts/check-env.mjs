import { readFileSync, existsSync } from 'node:fs';
import { basename, resolve } from 'node:path';

const envFile = process.argv[2] ?? '.env';
const envPath = resolve(envFile);
const isTemplate = basename(envPath) === '.env.example' || process.argv.includes('--template');
const fileEnv = existsSync(envPath) ? parseEnv(readFileSync(envPath, 'utf8')) : {};
const env = { ...fileEnv, ...process.env };

const required = [
  'NODE_ENV',
  'API_PORT',
  'DATABASE_URL',
  'REDIS_URL',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'ADMIN_API_BASE_URL',
];

const recommended = [
  'STORAGE_PROVIDER',
  'S3_ENDPOINT',
  'S3_REGION',
  'S3_BUCKET',
  'S3_ACCESS_KEY',
  'S3_SECRET_KEY',
  'S3_PUBLIC_BASE_URL',
  'SMS_PROVIDER',
  'SMS_API_URL',
  'SMS_API_KEY',
  'SMS_SENDER_ID',
  'MOMO_PARTNER_CODE',
  'MOMO_ACCESS_KEY',
  'MOMO_SECRET_KEY',
  'VNPAY_TMN_CODE',
  'VNPAY_HASH_SECRET',
  'SUPABASE_JWT_SECRET',
  'SUPABASE_JWT_AUDIENCE',
];

const insecureValues = new Set(['change-me', 'changeme', 'secret', 'password', '']);
const missingRequired = required.filter((key) => !env[key]);
const insecureRequired = required.filter((key) => insecureValues.has(String(env[key] ?? '').trim()));
const missingRecommended = recommended.filter((key) => !env[key]);

const result = {
  ok: missingRequired.length === 0 && (isTemplate || insecureRequired.length === 0),
  envFile: existsSync(envPath) ? envPath : null,
  mode: isTemplate ? 'template' : 'runtime',
  missingRequired,
  insecureRequired: isTemplate ? [] : insecureRequired,
  missingRecommended,
};

console.log(JSON.stringify(result, null, 2));

if (!result.ok) {
  process.exitCode = 1;
}

function parseEnv(source) {
  const entries = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }
    const index = line.indexOf('=');
    if (index === -1) {
      continue;
    }
    const key = line.slice(0, index).trim();
    const value = line
      .slice(index + 1)
      .trim()
      .replace(/^['"]|['"]$/g, '');
    entries[key] = value;
  }
  return entries;
}
