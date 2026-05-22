import { createHmac, randomUUID } from 'node:crypto';

const apiBaseUrl = process.env.API_BASE_URL ?? 'http://localhost:3000/api';
const jwtSecret = process.env.SUPABASE_JWT_SECRET;
const jwtAudience = process.env.SUPABASE_JWT_AUDIENCE ?? 'authenticated';

if (!jwtSecret) {
  throw new Error('SUPABASE_JWT_SECRET is required for the Supabase auth smoke test.');
}

const customerToken = signSupabaseToken({
  sub: `smoke-${randomUUID()}`,
  aud: jwtAudience,
  phone: `+849${Date.now().toString().slice(-8)}`,
  app_metadata: { role: 'CUSTOMER' },
  user_metadata: { role: 'CUSTOMER' },
});

const customer = await getJson('/customer/me', customerToken);

if (!customer?.id || !customer?.customerProfile) {
  throw new Error(`Supabase JWT did not map to a customer user: ${JSON.stringify(customer)}`);
}

console.log(
  JSON.stringify(
    {
      ok: true,
      authProvider: 'supabase',
      apiBaseUrl,
      customerUserId: customer.id,
      customerProfileId: customer.customerProfile.id,
    },
    null,
    2,
  ),
);

async function getJson(path, accessToken) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`GET ${path} failed: ${response.status} ${JSON.stringify(body)}`);
  }
  return body;
}

function signSupabaseToken(payload) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'HS256', typ: 'JWT' };
  const claims = {
    iss: 'supabase',
    iat: now,
    exp: now + 600,
    ...payload,
  };
  const encodedHeader = base64Url(JSON.stringify(header));
  const encodedPayload = base64Url(JSON.stringify(claims));
  const signature = createHmac('sha256', jwtSecret)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest('base64url');
  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}
