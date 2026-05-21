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

## FCM Adapter

The current adapter uses FCM HTTP v1 shape and can authorize requests in either of these ways:

```env
FCM_PROJECT_ID=
FCM_ACCESS_TOKEN=
FCM_SERVICE_ACCOUNT_FILE=
FCM_SERVICE_ACCOUNT_JSON=
FCM_SERVICE_ACCOUNT_JSON_BASE64=
```

Supported behavior:

- `FCM_ACCESS_TOKEN`: direct short-lived bearer token override
- `FCM_SERVICE_ACCOUNT_FILE`: absolute path to a Google service-account JSON file
- `FCM_SERVICE_ACCOUNT_JSON`: raw JSON string for the same file
- `FCM_SERVICE_ACCOUNT_JSON_BASE64`: base64-encoded JSON for secret managers

When a service account is provided, the API mints a short-lived OAuth 2.0 access token for the `https://www.googleapis.com/auth/firebase.messaging` scope and caches it until shortly before expiry.

Without `FCM_PROJECT_ID` and one of the credentials above, the worker records `FCM_DISABLED:SKIPPED` delivery attempts. This keeps local development safe and makes missing credentials visible in Admin Web.

For permanent FCM token failures such as `UNREGISTERED` and token-specific `INVALID_ARGUMENT`, the retry worker now disables that `PushDevice` so the same dead token stops consuming future retry jobs. Re-registering the token from the app enables it again.

## Mobile Firebase Removal Check

The repository includes `node infra/scripts/check-mobile-firebase.mjs` and the full local verifier runs it automatically. The check fails when either Flutter app still has Firebase packages, Google Services Gradle plugin usage, or `google-services.json`.

## Next Adapter Step

- Add notification templates per locale.
