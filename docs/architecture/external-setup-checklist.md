# HANDS External Setup Checklist

This checklist records the external accounts, keys, and console setup needed before HANDS moves from local MVP testing to real Vietnam-wide operation.

Keep secrets outside Git. The recommended local secret folder is:

```powershell
C:\dev\massage-vn-workspace\secrets
```

Use this staging template as the fill-in checklist when you receive external console values:

```text
C:\dev\massage-vn-workspace\repo\infra\env\hands-staging.env.example
```

## Project Identity

- App name: `HANDS`
- Service area: all Vietnam, starting with local MVP flows around Ho Chi Minh City
- Customer app languages planned later: Vietnamese, English, Korean, Chinese, Japanese
- Provider app language planned later: Vietnamese
- Admin languages planned later: Korean, Vietnamese, English

## 1. Push Notifications

The Flutter apps no longer use Firebase mobile SDKs. MVP notification behavior is in-app first, backed by persisted notification records.

Future OS-level push still needs a provider decision:

- Recommended direction: OneSignal or another push provider with a backend adapter
- Current backend adapter: `IN_APP_ONLY` in `apps/api/src/notifications/push-delivery.service.ts`
- Mobile apps should not restore `google-services.json` unless the push strategy changes intentionally

Planned provider value:

```dotenv
ONESIGNAL_APP_ID=
```

Verification:

```powershell
cd C:\dev\massage-vn-workspace\repo
node .\infra\scripts\check-mobile-firebase.mjs
npm.cmd run external:check:strict
```

## 2. Low-Cost Maps And Address Search

MVP map/location uses MapTiler + MapLibre and Geoapify instead of Google Maps.

Required accounts:

- MapTiler account and API key for map tiles/styles
- Geoapify account and API key for Vietnam address search/geocoding
- Supabase account is optional now because the MVP stores location through the NestJS API, but the SQL is ready under `infra/supabase/location-schema.sql`

Local run values:

```powershell
$env:MAPTILER_API_KEY="your-maptiler-key"
$env:GEOAPIFY_API_KEY="your-geoapify-key"
```

Supabase values used by Auth now and direct database/storage later:

```dotenv
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_JWT_SECRET=
SUPABASE_JWT_AUDIENCE=authenticated
SUPABASE_SERVICE_ROLE_KEY=
AUTH_BACKEND=nest
```

Recommended local auth setting while the product flow is still changing:

```dotenv
AUTH_BACKEND=nest
```

Switch mobile OTP to Supabase only after Supabase Phone Auth and the API JWT secret are configured:

```dotenv
AUTH_BACKEND=supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon-key>
SUPABASE_JWT_SECRET=<project-jwt-secret>
SUPABASE_JWT_AUDIENCE=authenticated
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>
```

The Flutter run scripts pass MapTiler and Geoapify keys as Dart defines:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\run-hands-emulator.ps1 -App customer
powershell -ExecutionPolicy Bypass -File .\infra\scripts\run-hands-emulator.ps1 -App provider
```

## 3. SMS / OTP

Development uses a fixed OTP:

```dotenv
SMS_PROVIDER=dev
DEV_OTP=123456
```

Production needs:

```dotenv
SMS_PROVIDER=your-provider
SMS_API_URL=https://provider.example/api
SMS_API_KEY=your-secret-key
SMS_SENDER_ID=HANDS
```

Decision still needed:

- Supabase Phone Auth SMS provider or a backend SMS provider
- OTP rate limits
- resend cooldown
- fraud monitoring rules

Supabase Auth setup:

1. Create or open the HANDS Supabase project.
2. Enable Phone provider in Authentication.
3. Configure the SMS provider supported by Supabase for Vietnam delivery.
4. Copy `Project URL`, `anon public`, and the JWT secret into the local `.env`.
5. Keep `AUTH_BACKEND=nest` until OTP sending is verified, then test `AUTH_BACKEND=supabase` on customer and provider apps.
6. Provider Supabase login must not rely on a client-selected role. A provider can exchange a Supabase session only if the phone number already belongs to an approved/local HANDS provider account or the admin provider-role sync has placed `PROVIDER` in Supabase user metadata.
7. After setting `SUPABASE_JWT_SECRET`, run `npm.cmd run auth:supabase-smoke` against the API to verify customer mapping, provider mapping, invalid audience rejection, and role escalation rejection.
8. Keep `SUPABASE_SERVICE_ROLE_KEY` only in the API environment. It is needed for admin provider-role sync and must never be sent to Flutter, browser JavaScript, or Git.

## 4. Payments

MVP supports:

- Cash
- MoMo
- VNPay

MoMo production values:

```dotenv
MOMO_PARTNER_CODE=
MOMO_ACCESS_KEY=
MOMO_SECRET_KEY=
```

VNPay production values:

```dotenv
VNPAY_TMN_CODE=
VNPAY_HASH_SECRET=
```

Before launch, confirm:

- authorization / release / capture behavior
- refund behavior
- callback URL
- return URL
- sandbox merchant separated from production merchant
- admin manual refund permissions

## 5. Storage / CDN

MVP can run on local MinIO. Production should use Supabase Storage S3, S3-compatible storage, or Cloudflare R2.

Required values:

```dotenv
STORAGE_PROVIDER=s3-compatible
S3_ENDPOINT=
S3_REGION=
S3_BUCKET=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_PUBLIC_BASE_URL=
```

Supabase Storage S3 example:

```dotenv
STORAGE_PROVIDER=supabase-storage-s3
S3_ENDPOINT=https://<project-ref>.storage.supabase.co/storage/v1/s3
S3_REGION=auto
S3_BUCKET=hands-files
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_PUBLIC_BASE_URL=https://<project-ref>.supabase.co/storage/v1/object/public/hands-files
```

Rules:

- Provider verification files stay private.
- Public provider profile media can be served through CDN.
- Never commit uploaded files or service account credentials.
- Supabase projects should use the generated staging SQL bundle so schema, buckets, and RLS policies are applied in the expected order.

Generate the bundle before applying Supabase SQL:

```powershell
cd C:\dev\massage-vn-workspace\repo
npm.cmd run supabase:sql:pack
```

Then paste this generated file into the Supabase SQL Editor:

```text
C:\dev\massage-vn-workspace\repo\infra\supabase\.generated\hands-staging-setup.sql
```

## 6. Domains / Deployment

Production preparation:

- API domain
- Admin domain
- TLS certificates
- Nginx reverse proxy
- CORS origin list
- production `.env`
- backup and restore schedule
- GitHub Actions later, after the MVP flow stabilizes

## 7. Admin Access

Local defaults:

```dotenv
ADMIN_API_BASE_URL=http://localhost:3100/api
ADMIN_DEMO_PHONE=+84900000099
ADMIN_DEMO_OTP=123456
```

Before launch:

- create real admin accounts
- disable demo OTP
- rotate JWT secrets
- define owner / operator / finance permissions
- enable audit log review for payout, refund, provider approval, and coupon changes

## One-Time Full Check

Generate the external registration pack first. It lists all accounts, console paths, Android package names, env values, and verification commands in one place:

```powershell
cd C:\dev\massage-vn-workspace\repo
npm.cmd run external:pack
npm.cmd run supabase:sql:pack
```

Run this before real device or emulator testing:

```powershell
cd C:\dev\massage-vn-workspace\repo
npm.cmd run external:check
powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices
```

Run phase-specific checks before each external E2E pass:

```powershell
npm.cmd run external:check:supabase
npm.cmd run external:check:maps
npm.cmd run external:check:payments
npm.cmd run external:check:storage
```

Run strict mode only before production-like E2E testing, because it requires every recommended external integration at once:

```powershell
npm.cmd run external:check:strict
```

## Current Local Status

Last checked from `C:\dev\massage-vn-workspace\repo` on 2026-05-22:

- Mobile Firebase dependencies/config: removed
- Full local verification with Docker services: passing
- OS-level push provider: not selected
- MapTiler API key: pending
- Geoapify API key: pending
- Supabase URL / anon key / JWT secret: pending for real Supabase OTP
- Mobile auth switch: still `AUTH_BACKEND=nest` locally until Supabase Phone Auth is configured
- Local MinIO storage: ready for MVP
- Production SMS provider: not selected
- MoMo / VNPay merchant credentials: not filled
- Production S3 or Cloudflare R2: not filled, local MinIO is enough for MVP

Phase-specific external checks currently block only on missing external console values:

- `supabase-auth`: `AUTH_BACKEND=supabase`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET`
- `maps`: `MAPTILER_API_KEY`, `GEOAPIFY_API_KEY`
- `payments`: `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY`, `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`

The next external setup items to complete are:

- Supabase URL / anon key / JWT secret for real OTP migration
- MapTiler API key
- Geoapify API key
- production push provider decision

## Recommended Fill Order

1. Supabase project URL / anon key / JWT secret
2. Supabase Phone Auth SMS configuration
3. MapTiler and Geoapify keys
4. MoMo and VNPay credentials
5. Storage / CDN credentials
6. Production push provider
7. Production domains and TLS
