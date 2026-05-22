import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const envFile = process.argv.find((arg) => arg.startsWith('--env='))?.slice('--env='.length) ?? '.env';
const strict = process.argv.includes('--strict');
const envPath = resolve(envFile);
const fileEnv = existsSync(envPath) ? parseEnv(readFileSync(envPath, 'utf8')) : {};
const env = { ...fileEnv, ...process.env };

const checks = [];

addCheck('workspace', 'project root', existsSync(resolve('package.json')), 'Run this script from C:\\dev\\massage-vn-workspace\\repo.');
addRecommended('push', 'production push provider', false, 'Choose OneSignal or another OS push provider before production launch.');

addRecommended(
  'maps',
  'MAPTILER_API_KEY',
  hasValue('MAPTILER_API_KEY'),
  'Set MAPTILER_API_KEY in .env or the shell before running Flutter with the MapTiler map.',
);
addRecommended(
  'geocoding',
  'GEOAPIFY_API_KEY',
  hasValue('GEOAPIFY_API_KEY'),
  'Set GEOAPIFY_API_KEY in .env or the shell before using address search.',
);

addRecommended('supabase', 'SUPABASE_URL', hasValue('SUPABASE_URL'), 'Set SUPABASE_URL if using Supabase directly for map/location storage.');
addRecommended('supabase', 'SUPABASE_ANON_KEY', hasValue('SUPABASE_ANON_KEY'), 'Set SUPABASE_ANON_KEY if using Supabase directly from clients.');

addRecommended('sms', 'SMS_PROVIDER', hasValue('SMS_PROVIDER'), 'Use SMS_PROVIDER=dev locally; choose a real SMS provider before launch.');
addRecommended('sms', 'SMS_API_URL', hasValue('SMS_API_URL'), 'Set the production SMS API URL before real OTP launch.');
addRecommended('sms', 'SMS_API_KEY', hasValue('SMS_API_KEY'), 'Set the production SMS API key before real OTP launch.');

addRecommended('payments', 'MoMo credentials', allHaveValue(['MOMO_PARTNER_CODE', 'MOMO_ACCESS_KEY', 'MOMO_SECRET_KEY']), 'Fill MoMo merchant credentials before MoMo E2E.');
addRecommended('payments', 'VNPay credentials', allHaveValue(['VNPAY_TMN_CODE', 'VNPAY_HASH_SECRET']), 'Fill VNPay merchant credentials before VNPay E2E.');

addRecommended(
  'storage',
  'S3-compatible storage',
  allHaveValue(['S3_ENDPOINT', 'S3_REGION', 'S3_BUCKET', 'S3_ACCESS_KEY', 'S3_SECRET_KEY', 'S3_PUBLIC_BASE_URL']),
  'Local MinIO is enough for MVP; fill production storage/CDN values before launch.',
);

const requiredFailures = checks.filter((check) => check.required && check.status !== 'PASS');
const recommendedFailures = checks.filter((check) => !check.required && check.status !== 'PASS');

const result = {
  ok: requiredFailures.length === 0 && (!strict || recommendedFailures.length === 0),
  mode: strict ? 'strict' : 'advisory',
  envFile: existsSync(envPath) ? envPath : null,
  checks,
  nextActions: [...requiredFailures, ...(strict ? recommendedFailures : [])].map((check) => check.fix),
};

console.log(JSON.stringify(result, null, 2));

if (!result.ok) {
  process.exitCode = 1;
}

function addCheck(category, name, passed, fix) {
  checks.push({
    category,
    name,
    required: true,
    status: passed ? 'PASS' : 'FAIL',
    fix,
  });
}

function addRecommended(category, name, passed, fix) {
  checks.push({
    category,
    name,
    required: false,
    status: passed ? 'PASS' : 'WARN',
    fix,
  });
}

function hasValue(key) {
  return String(env[key] ?? '').trim().length > 0;
}

function allHaveValue(keys) {
  return keys.every(hasValue);
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
    const value = line.slice(index + 1).trim().replace(/^['"]|['"]$/g, '');
    entries[key] = value;
  }
  return entries;
}
