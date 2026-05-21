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

## 1. Firebase Cloud Messaging

Use one Firebase project and register two Android apps:

- Customer package: `com.massagevn.customer.customer_app`
- Provider package: `com.massagevn.provider.provider_app`

Required files:

- `C:\dev\massage-vn-workspace\repo\apps\customer_app\android\app\google-services.json`
- `C:\dev\massage-vn-workspace\repo\apps\provider_app\android\app\google-services.json`

Recommended service account path:

```powershell
C:\dev\massage-vn-workspace\secrets\hands-firebase-adminsdk.json
```

Runtime `.env` values:

```dotenv
FCM_PROJECT_ID=your-firebase-project-id
FCM_SERVICE_ACCOUNT_FILE=C:\dev\massage-vn-workspace\secrets\hands-firebase-adminsdk.json
```

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

MVP can run on local MinIO. Production should use S3-compatible storage or Cloudflare R2.

Required values:

```dotenv
S3_ENDPOINT=
S3_REGION=
S3_BUCKET=
S3_ACCESS_KEY=
S3_SECRET_KEY=
S3_PUBLIC_BASE_URL=
```

Rules:

- Provider verification files stay private.
- Public provider profile media can be served through CDN.
- Never commit uploaded files or service account credentials.

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

- Firebase customer `google-services.json`: ready
- Firebase provider `google-services.json`: ready
- Firebase service account file: ready at `C:\dev\massage-vn-workspace\secrets\massage-vn-firebase-adminsdk.json`
- FCM project id: ready in local `.env`
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

## Recommended Fill Order

1. Firebase / FCM Android app configs
2. Firebase service account file
3. MapTiler and Geoapify keys
4. SMS provider
5. MoMo and VNPay credentials
6. Storage / CDN credentials
7. Production domains and TLS
