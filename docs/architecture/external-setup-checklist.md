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

## 2. Google Maps

Enable these APIs in Google Cloud:

- Maps SDK for Android
- Billing for the Google Cloud project

Create Android-restricted API keys. You can use one shared key for both apps in MVP, but production should prefer separate keys.

Android package restrictions:

- `com.massagevn.customer.customer_app`
- `com.massagevn.provider.provider_app`

Development SHA-1 currently recorded:

```text
E3:8D:6A:41:B9:0E:6D:E0:1C:8E:BA:5E:2D:4B:22:1E:0A:63:4E:18
```

Local run value:

```powershell
$env:MAPS_API_KEY="your-google-maps-android-key"
```

The Flutter run scripts pass this key to Android manifest placeholders and Dart config:

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

## Recommended Fill Order

1. Firebase / FCM Android app configs
2. Firebase service account file
3. Google Maps Android key
4. SMS provider
5. MoMo and VNPay credentials
6. Storage / CDN credentials
7. Production domains and TLS
