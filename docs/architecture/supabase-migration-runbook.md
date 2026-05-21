# Supabase Migration Runbook

## Purpose

HANDS will move away from Firebase and keep the Flutter apps behind Clean Architecture boundaries. Critical booking, payment, verification, and matching writes should continue through the NestJS API until the business flow is fully stable.

## Current Status

- Customer and Provider apps now have feature repositories for auth, discovery, booking, chat, map, notification, coupons, provider profile, earnings, and verification.
- `app_state.dart` is now a compatibility facade for existing screens rather than a direct API integration layer.
- Firebase is still used only by `firebase_push_token_datasource.dart` in each Flutter app.
- `supabase_flutter` is installed but no production flow depends on direct Supabase calls yet.

## Client Environment

Flutter run flags:

```powershell
--dart-define=SUPABASE_URL=https://your-project.supabase.co
--dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Existing local run flags still apply:

```powershell
--dart-define=API_BASE_URL=http://10.0.2.2:3000/api
--dart-define=SOCKET_BASE_URL=http://10.0.2.2:3000
--dart-define=MAPTILER_API_KEY=your-maptiler-key
--dart-define=GEOAPIFY_API_KEY=your-geoapify-key
```

## SQL

Run [hands-core-schema.sql](/C:/dev/massage-vn-workspace/repo/infra/supabase/hands-core-schema.sql) in the Supabase SQL editor after creating the project.

The schema includes:

- `profiles`
- `providers`
- `services`
- `provider_services`
- `provider_locations`
- `customer_selected_locations`
- `bookings`
- `booking_services`
- `booking_participants`
- `chat_rooms`
- `messages`
- `payments`
- `reviews`
- `notifications`
- `files`
- `admin_settings`

## Safe Migration Order

1. Keep NestJS OTP/JWT login as the mobile auth boundary.
2. Add Supabase PostgreSQL as the backing database under the API.
3. Move file metadata and verification uploads to Supabase Storage through the API.
4. Replace FCM token datasource with in-app notifications first.
5. Add OneSignal or another push provider later for OS-level push.
6. Move chat history to Supabase tables, while keeping Socket.IO events until delivery semantics are validated.
7. Remove Firebase packages and `google-services.json` only after push replacement is verified on emulator and real device.

## Risk Notes

- Supabase Realtime is not an OS push notification replacement.
- RLS is a guardrail, not the only security layer. Booking finalization, matching, refunds, and payment capture must remain server-owned.
- Direct mobile Supabase writes should be limited to low-risk data until RLS and audit logging are verified.
