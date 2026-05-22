# Supabase Migration Runbook

## Purpose

HANDS will move away from Firebase and keep the Flutter apps behind Clean Architecture boundaries. Critical booking, payment, verification, and matching writes should continue through the NestJS API until the business flow is fully stable.

## Current Status

- Customer and Provider apps now have feature repositories for auth, discovery, booking, chat, map, notification, coupons, provider profile, earnings, and verification.
- `app_state.dart` is now a compatibility facade for existing screens rather than a direct API integration layer.
- Mobile Firebase packages, Android Google Services config, and Flutter Firebase imports have been removed.
- API FCM HTTP delivery has been removed and replaced with in-app-only delivery records.
- Mobile apps currently use in-app notifications instead of OS-level push tokens.
- `supabase_flutter` is installed but no production flow depends on direct Supabase calls yet.

## Client Environment

Flutter run flags:

```powershell
--dart-define=SUPABASE_URL=https://your-project.supabase.co
--dart-define=SUPABASE_ANON_KEY=your-anon-key
--dart-define=AUTH_BACKEND=nest
API env:
SUPABASE_JWT_SECRET=your-project-jwt-secret
SUPABASE_JWT_AUDIENCE=authenticated
```

Existing local run flags still apply:

```powershell
--dart-define=API_BASE_URL=http://10.0.2.2:3000/api
--dart-define=SOCKET_BASE_URL=http://10.0.2.2:3000
--dart-define=MAPTILER_API_KEY=your-maptiler-key
--dart-define=GEOAPIFY_API_KEY=your-geoapify-key
```

Auth backend modes:

- `AUTH_BACKEND=nest` keeps the current NestJS OTP/JWT flow and is the default for MVP stability.
- `AUTH_BACKEND=supabase` routes mobile OTP verification through Supabase Auth. Use this only after Supabase phone OTP is configured and the backend API accepts the resulting Supabase JWT or an exchange flow is added.

The API now accepts Supabase Auth JWTs when `SUPABASE_JWT_SECRET` is configured. Supabase users are mapped to local Nest users through `User.supabaseUserId`, and phone OTP users are linked by phone number when possible.

After the API is running with the same `SUPABASE_JWT_SECRET`, run this smoke test to verify that Supabase-style access tokens are accepted by protected Nest routes:

```powershell
$env:API_BASE_URL="http://localhost:3000/api"
$env:SUPABASE_JWT_SECRET="your-project-jwt-secret"
$env:SUPABASE_JWT_AUDIENCE="authenticated"
npm.cmd run auth:supabase-smoke
```

The emulator/device scripts pass these values from shell environment variables when present:

```powershell
$env:AUTH_BACKEND="nest"
$env:SUPABASE_URL="https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY="your-anon-key"
powershell -ExecutionPolicy Bypass -File .\infra\scripts\run-hands-emulator.ps1 -App customer
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

Storage policies are separated into `infra/supabase/storage-schema.sql` so bucket setup can be reviewed independently from app data tables.

## Safe Migration Order

1. Keep NestJS OTP/JWT login as the mobile auth boundary.
2. Add Supabase PostgreSQL as the backing database under the API.
3. Move file metadata and verification uploads to Supabase Storage through the API.
4. Keep mobile notifications as in-app rows first.
5. Add OneSignal or another push provider later for OS-level push.
6. Move chat history to Supabase tables, while keeping Socket.IO events until delivery semantics are validated.
7. Add OneSignal or another production push provider behind `PushDeliveryService` after launch requirements are clear.

## Risk Notes

- Supabase Realtime is not an OS push notification replacement.
- RLS is a guardrail, not the only security layer. Booking finalization, matching, refunds, and payment capture must remain server-owned.
- Direct mobile Supabase writes should be limited to low-risk data until RLS and audit logging are verified.
