# API Route Plan

Protected routes require:

```http
Authorization: Bearer <accessToken>
```

Local MVP auth uses `POST /auth/verify-otp` with dev OTP `123456`.

## Auth

- `GET /health`
- `GET /health/ready`
- `POST /auth/request-otp`
- `POST /auth/verify-otp`
- `POST /auth/refresh`

## Customer

- `GET /customer/me`
- `PATCH /customer/me`
- `GET /customer/providers/nearby`
- `GET /customer/providers/:id`
- `POST /customer/bookings`
- `GET /customer/bookings/:id`
- `POST /customer/bookings/:id/cancel`
- `POST /customer/bookings/:id/select-provider`
- `POST /customer/reviews`

## Provider

- `GET /provider/me`
- `PATCH /provider/me`
- `POST /provider/online`
- `POST /provider/offline`
- `POST /provider/location`
- `GET /provider/verification`
- `POST /provider/verification/submit`
- `GET /provider/bookings/open`
- `POST /provider/bookings/:id/join`
- `POST /provider/bookings/:id/accept`
- `POST /provider/bookings/:id/reject`
- `POST /provider/bookings/:id/arrived`
- `POST /provider/bookings/:id/start`
- `POST /provider/bookings/:id/complete`
- `GET /provider/earnings`
- `GET /provider/earnings/summary`
- `GET /provider/earnings/payout-batches`

## Chat

- `GET /chat/rooms/:id/messages`
- `POST /chat/rooms/:id/messages`

Chat access is limited to the booking customer, the selected provider, and admins.

## Files

- `POST /files/presign`
- `GET /files/:id/read-url`

Provider verification files must be private. Public provider gallery/profile images can later be served through CDN.

For `provider-verification` uploads, providers may omit `providerVerificationId`; the API resolves or creates the provider's verification record automatically.

## Notifications

- `GET /notifications`
- `PATCH /notifications/:id/read`
- `PATCH /notifications/device-token/register`
- `POST /notifications/device-token/register`

The retry queue stores DB notifications first. FCM delivery should use registered `PushDevice` rows in the next provider adapter step.

## Admin

- `GET /admin/users`
- `GET /admin/providers`
- `POST /admin/providers/:id/approve`
- `POST /admin/providers/:id/reject`
- `GET /admin/bookings`
- `GET /admin/payments`
- `POST /admin/payments/:id/refund`
- `GET /admin/refunds`
- `GET /admin/earnings`
- `GET /admin/earnings/summary`
- `POST /admin/earnings/:id/mark-paid`
- `GET /admin/payout-batches`
- `POST /admin/payout-batches`
- `GET /admin/reviews`
- `PATCH /admin/reviews/:id/moderate`
- `GET /admin/notifications`

## Payments

- `POST /payments/MOMO/callback`
- `POST /payments/VNPAY/callback`
- `POST /payments/CASH/callback`

Callbacks are placeholder parser routes in the MVP. Real MoMo/VNPay signature validation must be added before production.

Manual admin refunds move the payment to `REFUNDED`, mark the booking as `REFUNDED`, create a `Refund` row, and cancel unpaid provider earnings for that booking.
