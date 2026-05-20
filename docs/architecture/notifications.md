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

Tokens are stored in `PushDevice` and are now wired to the Android Firebase setup path used by both Flutter apps.

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

## Android App Setup

Both Flutter Android apps now apply the Google Services Gradle plugin:

- `apps/customer_app/android/app/google-services.json`
- `apps/provider_app/android/app/google-services.json`

Expected Android package names:

- `com.massagevn.customer.customer_app`
- `com.massagevn.provider.provider_app`

The repository includes `node infra/scripts/check-mobile-firebase.mjs` and the full local verifier runs it automatically. The check fails when:

- `google-services.json` is missing
- the Google Services Gradle plugin is not applied
- the Firebase package name does not match the app `applicationId`

## Next Adapter Step

- Disable invalid device tokens when FCM reports permanent token errors.
- Add notification templates per locale.
