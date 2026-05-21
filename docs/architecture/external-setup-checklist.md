# External Setup Checklist

이 문서는 HANDS를 로컬 MVP에서 실제 운영 단계로 올릴 때 필요한 외부 등록 항목을 한 번에 처리할 수 있도록 정리한 체크리스트입니다.

## 1. Google Maps

### Android Maps SDK

- Google Cloud Console에서 `Maps SDK for Android` 활성화
- Billing 연결
- Android API key 생성 후 `Android apps` 제한 적용

등록할 패키지 이름:

- Customer: `com.massagevn.customer.customer_app`
- Provider: `com.massagevn.provider.provider_app`

현재 개발용 SHA-1:

- `E3:8D:6A:41:B9:0E:6D:E0:1C:8E:BA:5E:2D:4B:22:1E:0A:63:4E:18`

로컬 실행 시 환경변수:

- `MAPS_API_KEY=<your-google-maps-android-key>`

## 2. Firebase Cloud Messaging

같은 Firebase 프로젝트에 아래 Android 앱 2개 등록:

- Customer: `com.massagevn.customer.customer_app`
- Provider: `com.massagevn.provider.provider_app`

필수 파일 배치:

- `C:\dev\massage-vn-workspace\repo\apps\customer_app\android\app\google-services.json`
- `C:\dev\massage-vn-workspace\repo\apps\provider_app\android\app\google-services.json`

서비스 계정 JSON 보관 위치 권장:

- `C:\dev\massage-vn-workspace\secrets\massage-vn-firebase-adminsdk.json`

필수 `.env` 값:

- `FCM_PROJECT_ID`
- `FCM_SERVICE_ACCOUNT_FILE`

선택 대안:

- `FCM_SERVICE_ACCOUNT_JSON`
- `FCM_SERVICE_ACCOUNT_JSON_BASE64`

## 3. SMS / OTP Provider

실운영 OTP를 위해 아래 항목 준비:

- `SMS_PROVIDER`
- `SMS_API_URL`
- `SMS_API_KEY`
- `SMS_SENDER_ID`

현재 개발 모드에서는:

- `SMS_PROVIDER=dev`
- `DEV_OTP=123456`

## 4. Payments

### MoMo

필수 값:

- `MOMO_PARTNER_CODE`
- `MOMO_ACCESS_KEY`
- `MOMO_SECRET_KEY`

### VNPay

필수 값:

- `VNPAY_TMN_CODE`
- `VNPAY_HASH_SECRET`

운영 전 확인:

- 승인/보류/취소/환불 정책
- callback / return URL
- 테스트 merchant와 운영 merchant 분리

## 5. Storage / CDN

필수 값:

- `S3_ENDPOINT`
- `S3_REGION`
- `S3_BUCKET`
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `S3_PUBLIC_BASE_URL`

운영 체크:

- provider verification 파일은 private
- public provider assets는 CDN 경유

## 6. Domains / Deployment

운영 전 준비:

- API 도메인
- Admin 도메인
- TLS 인증서
- Nginx reverse proxy 설정
- CORS origin 목록
- production `.env`

## 7. Admin Access / Demo Accounts

현재 로컬 기준:

- `ADMIN_API_BASE_URL=http://localhost:3100/api`
- `ADMIN_DEMO_PHONE=+84900000099`
- `ADMIN_DEMO_OTP=123456`

운영 전에는:

- 실제 admin 계정 분리
- 데모 OTP 제거
- 강한 JWT secret 교체

## 8. One-Time Verification Commands

Firebase 설정 확인:

```powershell
cd C:\dev\massage-vn-workspace\repo
node .\infra\scripts\check-mobile-firebase.mjs
```

환경변수 확인:

```powershell
cd C:\dev\massage-vn-workspace\repo
node .\infra\scripts\check-env.mjs
```

전체 로컬 검증:

```powershell
cd C:\dev\massage-vn-workspace\repo
powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices
```

## 9. Current Project Defaults

- 앱 이름: `HANDS`
- 서비스 범위: 베트남 전지역
- 표준 로컬 API: `http://localhost:3100/api`
- 표준 로컬 Admin: `http://localhost:3101`

## 10. Recommended Fill Order

1. Firebase / FCM
2. Google Maps
3. SMS provider
4. MoMo / VNPay
5. Storage / CDN
6. Domain / TLS / deploy
