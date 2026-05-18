# Notifications

## Current MVP

The API creates persistent `Notification` rows for booking lifecycle events:

- `booking.opened`
- `provider.joined`
- `booking.matched`
- `service.completed`

Each notification schedules a `notification-retry` BullMQ job. The worker records one `NotificationDelivery` attempt per enabled device token.

## Device Tokens

Mobile apps can register FCM/APNs/web push tokens through:

```http
PATCH /api/notifications/device-token/register
Authorization: Bearer <accessToken>
Content-Type: application/json

{
  "token": "device-token",
  "platform": "android"
}
```

Tokens are stored in `PushDevice` and can be used by a future Firebase adapter.

## FCM Adapter

The current adapter uses FCM HTTP v1 shape and is enabled only when both values exist:

```env
FCM_PROJECT_ID=
FCM_ACCESS_TOKEN=
```

Without those values, the worker records `FCM_DISABLED:SKIPPED` delivery attempts. This keeps local development safe and makes missing credentials visible in Admin Web.

## Next Adapter Step

- Replace manual `FCM_ACCESS_TOKEN` with a service-account token provider.
- Add token refresh.
- Disable invalid device tokens when FCM reports permanent token errors.
- Add notification templates per locale.
