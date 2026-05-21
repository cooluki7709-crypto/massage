# Flutter Clean Architecture and Supabase Migration

## Goal

Move the HANDS customer and provider Flutter apps from the current mixed app-state structure to a DDD/Clean Architecture layout, then remove Firebase and migrate platform dependencies to Supabase-backed services without breaking the current MVP flow.

## Current Firebase Usage

The Flutter apps currently use Firebase only for FCM device token registration.

| App | File | Current responsibility |
| --- | --- | --- |
| Customer | `apps/customer_app/lib/src/features/notification/data/datasources/firebase_push_token_datasource.dart` | Initializes Firebase Messaging and reads the current device token. |
| Provider | `apps/provider_app/lib/src/features/notification/data/datasources/firebase_push_token_datasource.dart` | Initializes Firebase Messaging and reads the current device token. |
| Customer Android | `apps/customer_app/android/app/google-services.json` | Firebase Android client config. |
| Provider Android | `apps/provider_app/android/app/google-services.json` | Firebase Android client config. |
| API | `apps/api/src/notifications/fcm-push.service.ts` | Sends FCM HTTP v1 push messages and records delivery state. |

No Flutter code currently uses Firebase Auth, Firestore, Firebase Storage, Realtime Database, or Cloud Functions.

## Target Client Structure

Each Flutter app should gradually move toward this layout:

```text
lib/
  src/
    core/
      config/
      error/
      network/
      providers.dart
      router/
      theme/
      utils/
      widgets/
    features/
      auth/
        domain/
        data/
        presentation/
      user/
      provider/
      booking/
      map/
      chat/
      notification/
      payment/
      file/
      review/
```

## Migration Strategy

Do not remove Firebase immediately. First isolate each external dependency behind feature repositories and use cases.

1. Notification boundary
   - Keep Firebase Messaging temporarily.
   - Hide Firebase behind `PushTokenDataSource`.
   - Keep UI calling `RegisterCurrentDevicePushToken`.
   - Later replace Firebase datasource with an internal notification or OneSignal datasource.

2. Auth boundary
   - Keep current NestJS OTP/JWT login during MVP stabilization.
   - Introduce `AuthRepository` and `SignInWithOtp` use case.
   - Later switch the datasource to Supabase Auth or to a NestJS endpoint backed by Supabase Auth.

3. Map/location boundary
   - Keep MapTiler, Geoapify, Geolocator.
   - Move location selection and provider heartbeat logic under `features/map`.
   - Store selected customer locations and provider last-known locations in PostgreSQL/Supabase tables.

4. Booking boundary
   - Keep booking, direct request, provider accept, backup matching, and chat-unlock behavior in the API.
   - Move Flutter API calls into `BookingRepository`.

5. Chat boundary
   - Keep Socket.IO until the MVP flow is stable.
   - Add a `ChatRepository` boundary.
   - Later evaluate Supabase Realtime for message subscription only.

6. File/storage boundary
   - Keep current presigned upload flow first.
   - Replace S3/MinIO adapter with Supabase Storage adapter when verification UX is stable.

7. Firebase removal
   - Remove mobile Firebase packages and Gradle plugin only after notification behavior is fully replaced.
   - Remove API FCM service after the replacement push adapter is verified.

## Supabase Data Model Direction

Recommended Supabase/PostgreSQL tables:

| Table | Purpose |
| --- | --- |
| `profiles` | Shared user profile linked to Supabase Auth user id. |
| `providers` | Provider profile, verification state, status, public profile data. |
| `services` | Massage service catalog. |
| `provider_services` | Provider-specific offerings and prices. |
| `provider_locations` | Last-known provider location and freshness timestamp. |
| `customer_selected_locations` | Customer-confirmed booking locations. |
| `bookings` | Direct booking and matching state. |
| `booking_participants` | Preferred and backup provider participation. |
| `payments` | Cash, MoMo, VNPay, refund/capture state. |
| `reviews` | Customer review and rating records. |
| `chat_rooms` | Booking chat room. |
| `messages` | Chat messages. |
| `notifications` | In-app notification inbox. |
| `files` | Supabase Storage file metadata. |
| `admin_settings` | Operational configuration. |

## RLS Direction

Use RLS as a second guardrail, but keep critical booking/payment/matching decisions in the API.

| Area | Policy direction |
| --- | --- |
| Profiles | Users can read/update their own profile. Admins can read all. |
| Providers | Public approved profile fields are readable by customers. Providers can update their own private profile. |
| Bookings | Customers see their own bookings. Providers see assigned, preferred, or open eligible bookings. Admins see all. |
| Messages | Only chat room participants and admins can read/write messages. |
| Notifications | Users read/update their own notification rows. Admins can inspect all. |
| Files | Owners and admins can access private files. Public provider media can be served through a public bucket/CDN. |

## Biggest Risks

- Push notification replacement: Supabase Realtime is not a full replacement for OS-level push when the app is closed.
- Auth migration: Supabase Auth JWT and current NestJS JWT must not diverge.
- Booking and payment security: never let mobile clients directly decide match/payment final state.
- Chat realtime migration: Socket.IO events and Supabase Realtime subscriptions have different delivery semantics.
- RLS mistakes: policies can accidentally hide legitimate records or expose private records.

## Recommended Architecture Decision

For the MVP, prefer this direction:

```text
Flutter apps -> Feature repositories/use cases -> NestJS API -> Supabase Postgres/Storage/Auth
```

Use direct Supabase client calls only for low-risk reads or realtime subscriptions after the API ownership boundary is clear.
