# HANDS External Setup Checklist

This checklist records the external accounts, keys, and console setup needed before HANDS moves from local MVP testing to real Vietnam-wide operation.

Keep secrets outside Git. The recommended local secret folder is:

```powershell
C:\dev\massage-vn-workspace\secrets
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

Verification:

```powershell
cd C:\dev\massage-vn-workspace\repo
node .\infra\scripts\check-mobile-firebase.mjs
node .\infra\scripts\check-external-setup.mjs --strict
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

Optional direct Supabase values:

```dotenv
SUPABASE_URL=
SUPABASE_ANON_KEY=
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

- Vietnam SMS provider
- OTP rate limits
- resend cooldown
- fraud monitoring rules

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
- Supabase projects should run `infra/supabase/hands-core-schema.sql` first, then `infra/supabase/storage-schema.sql`.

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

Run this before real device or emulator testing:

```powershell
cd C:\dev\massage-vn-workspace\repo
node .\infra\scripts\check-external-setup.mjs
powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices
```

Run strict mode before production-like E2E testing:

```powershell
node .\infra\scripts\check-external-setup.mjs --strict
```

## Current Local Status

Last checked from `C:\dev\massage-vn-workspace\repo`:

- Mobile Firebase dependencies/config: removed
- OS-level push provider: not selected
- MapTiler API key: pending
- Geoapify API key: pending
- Supabase URL / anon key: optional for later direct Supabase location storage
- Local MinIO storage: ready for MVP
- Production SMS provider: not selected
- MoMo / VNPay merchant credentials: not filled
- Production S3 or Cloudflare R2: not filled, local MinIO is enough for MVP

The next external setup items to complete are:

- MapTiler API key
- Geoapify API key
- optional Supabase project if direct client storage is preferred later
- production push provider decision

## Recommended Fill Order

1. MapTiler and Geoapify keys
2. Supabase project URL / anon key when direct client reads are enabled
3. SMS provider
4. MoMo and VNPay credentials
5. Storage / CDN credentials
6. Production push provider
7. Production domains and TLS
