# Notifications

## Current MVP

The API creates persistent `Notification` rows for booking lifecycle events:

- `booking.opened`
- `provider.joined`
- `booking.matched`
- `service.completed`

Each notification schedules a `notification-retry` BullMQ job. The worker records one `NotificationDelivery` attempt per enabled device token.

## In-App Notifications

The Flutter apps currently use in-app notification state only. They no longer bundle Firebase packages, `google-services.json`, or the Google Services Gradle plugin.

The backend route for registering OS push tokens still exists for a future push provider adapter:

```http
PATCH /api/notifications/device-token/register
Authorization: Bearer <accessToken>
Content-Type: application/json

{
  "token": "device-token",
  "platform": "android"
}
```

Tokens are stored in `PushDevice` when a production push provider is enabled. The current mobile apps do not call this route during automatic notification setup.

## Delivery Adapter

The current delivery adapter is intentionally `IN_APP_ONLY` through `PUSH_PROVIDER=in_app_only`.
It records a skipped delivery attempt for existing enabled `PushDevice` rows and does not call Firebase, Google, OneSignal, or any external push provider.

This keeps the local retry/audit flow visible in Admin Web while avoiding paid or vendor-specific push dependencies during the MVP.

Production OS push should be enabled explicitly:

```dotenv
PUSH_PROVIDER=onesignal
ONESIGNAL_APP_ID=
ONESIGNAL_REST_API_KEY=
```

`ONESIGNAL_REST_API_KEY` is server-side only. It must never be sent to Flutter, admin browser JavaScript, or Git.
Until the OneSignal HTTP adapter is implemented, selecting `PUSH_PROVIDER=onesignal` records a failed provider attempt with `PUSH_PROVIDER_ADAPTER_PENDING` instead of silently pretending push was delivered.

When a production provider is selected, keep the replacement behind `PushDeliveryService` and preserve this contract:

- create the in-app `Notification` row before any OS push attempt
- record every provider attempt in `NotificationDelivery`
- disable only the specific `PushDevice` that receives a permanent provider token failure
- keep retry behavior in BullMQ so booking and matching APIs do not wait on push latency

## Mobile Firebase Removal Check

The repository includes `node infra/scripts/check-mobile-firebase.mjs` and the full local verifier runs it automatically. The check fails when either Flutter app still has Firebase packages, Google Services Gradle plugin usage, or `google-services.json`.

## Next Adapter Step

- Add notification templates per locale.
- Implement the OneSignal HTTP adapter behind `PushDeliveryService` after OneSignal app credentials and mobile SDK decisions are confirmed.
