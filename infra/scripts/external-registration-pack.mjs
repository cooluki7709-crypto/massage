import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const envFile = process.argv.find((arg) => arg.startsWith('--env='))?.slice('--env='.length) ?? '.env';
const format =
  process.argv.find((arg) => arg.startsWith('--format='))?.slice('--format='.length) ?? 'markdown';
const envPath = resolve(envFile);
const fileEnv = existsSync(envPath) ? parseEnv(readFileSync(envPath, 'utf8')) : {};
const env = { ...fileEnv, ...process.env };

const registrationItems = [
  {
    order: 1,
    category: 'Supabase',
    account: 'Supabase project',
    purpose: 'Phone OTP, future PostgreSQL/RLS, Storage, and Realtime migration.',
    consolePath: 'Supabase Dashboard > Project Settings > API and Authentication > Providers > Phone',
    env: [
      envItem('AUTH_BACKEND', 'supabase', env.AUTH_BACKEND === 'supabase'),
      envItem('SUPABASE_URL', 'https://<project-ref>.supabase.co', isHttpsUrl(env.SUPABASE_URL)),
      envItem('SUPABASE_ANON_KEY', '<anon-public-key>', hasValue(env.SUPABASE_ANON_KEY)),
      envItem('SUPABASE_JWT_SECRET', '<project-jwt-secret>', isSecretLikeValue(env.SUPABASE_JWT_SECRET)),
      envItem(
        'SUPABASE_SERVICE_ROLE_KEY',
        '<service-role-key-server-only>',
        isSecretLikeValue(env.SUPABASE_SERVICE_ROLE_KEY),
      ),
    ],
    setup: [
      'Create a staging project named HANDS.',
      'Enable Phone Auth and configure a Vietnam-capable SMS provider.',
      'Run infra/supabase/hands-core-schema.sql, then storage-schema.sql in the SQL editor.',
      'Keep the service role key only in the API environment.',
    ],
    verify: ['npm.cmd run external:check:supabase', 'npm.cmd run auth:supabase-smoke'],
  },
  {
    order: 2,
    category: 'Maps',
    account: 'MapTiler',
    purpose: 'Low-cost map tile/style rendering for customer and provider mobile screens.',
    consolePath: 'MapTiler Cloud > Account > Keys',
    env: [envItem('MAPTILER_API_KEY', '<maptiler-key>', hasValue(env.MAPTILER_API_KEY))],
    setup: [
      'Create a browser/mobile key for HANDS staging.',
      'Use map tiles only; do not enable paid routing/directions for MVP.',
    ],
    verify: [
      'npm.cmd run external:check:maps',
      'powershell -ExecutionPolicy Bypass -File .\\infra\\scripts\\run-hands-emulator.ps1 -App customer',
    ],
  },
  {
    order: 3,
    category: 'Geocoding',
    account: 'Geoapify',
    purpose: 'Vietnam address search and coordinate lookup.',
    consolePath: 'Geoapify Dashboard > API Keys',
    env: [envItem('GEOAPIFY_API_KEY', '<geoapify-key>', hasValue(env.GEOAPIFY_API_KEY))],
    setup: [
      'Create a key for staging mobile address search.',
      'Keep debounce and result caching enabled in the mobile app to control cost.',
    ],
    verify: ['npm.cmd run external:check:maps'],
  },
  {
    order: 4,
    category: 'Payments',
    account: 'MoMo merchant sandbox',
    purpose: 'Vietnam wallet authorization, release, capture, and refund testing.',
    consolePath: 'MoMo Merchant Portal > Integration credentials',
    env: [
      envItem('MOMO_PARTNER_CODE', '<momo-partner-code>', hasValue(env.MOMO_PARTNER_CODE)),
      envItem('MOMO_ACCESS_KEY', '<momo-access-key>', hasValue(env.MOMO_ACCESS_KEY)),
      envItem('MOMO_SECRET_KEY', '<momo-secret-key>', hasValue(env.MOMO_SECRET_KEY)),
    ],
    setup: ['Start with sandbox credentials.', 'Keep cash payment enabled as operational fallback.'],
    verify: ['npm.cmd run external:check:payments', 'node infra\\scripts\\api-smoke.mjs'],
  },
  {
    order: 5,
    category: 'Payments',
    account: 'VNPay merchant sandbox',
    purpose: 'Vietnam card/bank payment authorization and refund testing.',
    consolePath: 'VNPay Merchant Portal > Integration credentials',
    env: [
      envItem('VNPAY_TMN_CODE', '<vnpay-tmn-code>', hasValue(env.VNPAY_TMN_CODE)),
      envItem('VNPAY_HASH_SECRET', '<vnpay-hash-secret>', hasValue(env.VNPAY_HASH_SECRET)),
    ],
    setup: ['Start with sandbox credentials.', 'Confirm callback and return URLs after domains are chosen.'],
    verify: ['npm.cmd run external:check:payments', 'node infra\\scripts\\api-smoke.mjs'],
  },
  {
    order: 6,
    category: 'Storage',
    account: 'Supabase Storage S3, R2, or S3-compatible bucket',
    purpose: 'Provider verification files, public profile media, and moderation evidence.',
    consolePath: 'Supabase Storage / Cloudflare R2 / S3-compatible console',
    env: [
      envItem('STORAGE_PROVIDER', 'supabase-storage-s3', hasValue(env.STORAGE_PROVIDER)),
      envItem(
        'S3_ENDPOINT',
        'https://<project-ref>.storage.supabase.co/storage/v1/s3',
        hasValue(env.S3_ENDPOINT),
      ),
      envItem('S3_REGION', 'auto', hasValue(env.S3_REGION)),
      envItem('S3_BUCKET', '<bucket-name>', hasValue(env.S3_BUCKET)),
      envItem('S3_ACCESS_KEY', '<storage-access-key>', hasValue(env.S3_ACCESS_KEY)),
      envItem('S3_SECRET_KEY', '<storage-secret-key>', hasValue(env.S3_SECRET_KEY)),
      envItem('S3_PUBLIC_BASE_URL', '<public-cdn-or-bucket-url>', hasValue(env.S3_PUBLIC_BASE_URL)),
    ],
    setup: [
      'Keep verification files private.',
      'Serve approved provider public media through CDN/public bucket URL.',
    ],
    verify: [
      'npm.cmd run external:check:storage',
      'powershell -ExecutionPolicy Bypass -File .\\infra\\scripts\\verify-local.ps1 -WithServices',
    ],
  },
  {
    order: 7,
    category: 'Push',
    account: 'OneSignal or equivalent push provider',
    purpose: 'Native OS push after Firebase Messaging removal.',
    consolePath: 'OneSignal Dashboard > App Settings',
    env: [envItem('ONESIGNAL_APP_ID', '<onesignal-app-id>', hasValue(env.ONESIGNAL_APP_ID))],
    setup: [
      'Choose the production push provider before launch.',
      'Keep the current API delivery adapter in-app-only until provider credentials are ready.',
    ],
    verify: ['npm.cmd run external:check:production'],
  },
  {
    order: 8,
    category: 'SMS',
    account: 'Vietnam-capable SMS provider',
    purpose: 'Real OTP delivery if not handled fully through Supabase Phone Auth.',
    consolePath: 'Chosen SMS vendor console',
    env: [
      envItem('SMS_PROVIDER', '<provider-name>', hasValue(env.SMS_PROVIDER)),
      envItem('SMS_API_URL', 'https://<sms-provider-api>', hasValue(env.SMS_API_URL)),
      envItem('SMS_API_KEY', '<sms-api-key>', hasValue(env.SMS_API_KEY)),
      envItem('SMS_SENDER_ID', 'HANDS', hasValue(env.SMS_SENDER_ID)),
    ],
    setup: ['Confirm Vietnam delivery rates and sender ID rules.', 'Define OTP resend and abuse limits.'],
    verify: ['npm.cmd run external:check:production'],
  },
];

const output = {
  ok: true,
  project: {
    appName: 'HANDS',
    serviceArea: 'Vietnam nationwide',
    workspace: 'C:\\dev\\massage-vn-workspace\\repo',
    secretFolder: 'C:\\dev\\massage-vn-workspace\\secrets',
    androidApplicationIds: {
      customer: 'com.massagevn.customer.customer_app',
      provider: 'com.massagevn.provider.provider_app',
    },
  },
  summary: {
    total: registrationItems.length,
    ready: registrationItems.filter((item) => item.env.every((entry) => entry.configured)).length,
    pending: registrationItems.filter((item) => item.env.some((entry) => !entry.configured)).length,
  },
  registrationItems,
};

if (format === 'json') {
  console.log(JSON.stringify(output, null, 2));
} else {
  console.log(toMarkdown(output));
}

function toMarkdown(pack) {
  const lines = [
    '# HANDS External Registration Pack',
    '',
    `- App: ${pack.project.appName}`,
    `- Service area: ${pack.project.serviceArea}`,
    `- Workspace: \`${pack.project.workspace}\``,
    `- Secret folder: \`${pack.project.secretFolder}\``,
    `- Customer Android package: \`${pack.project.androidApplicationIds.customer}\``,
    `- Provider Android package: \`${pack.project.androidApplicationIds.provider}\``,
    '',
    `Status: ${pack.summary.ready}/${pack.summary.total} account group(s) configured, ${pack.summary.pending} pending.`,
    '',
  ];

  for (const item of pack.registrationItems) {
    lines.push(`## ${item.order}. ${item.category}: ${item.account}`);
    lines.push('');
    lines.push(`Purpose: ${item.purpose}`);
    lines.push('');
    lines.push(`Console: ${item.consolePath}`);
    lines.push('');
    lines.push('Environment values:');
    for (const entry of item.env) {
      lines.push(`- [${entry.configured ? 'x' : ' '}] \`${entry.name}\` = \`${entry.example}\``);
    }
    lines.push('');
    lines.push('Setup notes:');
    for (const note of item.setup) {
      lines.push(`- ${note}`);
    }
    lines.push('');
    lines.push('Verify:');
    for (const command of item.verify) {
      lines.push(`- \`${command}\``);
    }
    lines.push('');
  }

  return lines.join('\n');
}

function envItem(name, example, configured) {
  return { name, example, configured };
}

function hasValue(value) {
  return String(value ?? '').trim().length > 0;
}

function isSecretLikeValue(value) {
  const normalized = String(value ?? '').trim();
  return normalized.length >= 16 && !/^change-me$/i.test(normalized);
}

function isHttpsUrl(value) {
  const normalized = String(value ?? '').trim();
  if (!normalized) {
    return false;
  }
  try {
    return new URL(normalized).protocol === 'https:';
  } catch {
    return false;
  }
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
