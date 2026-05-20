# Mobile API Integration

## Customer App

The customer Flutter app now includes:

- Demo OTP login against `POST /api/auth/verify-otp`
- JWT storage in Riverpod state for the current runtime session
- API client with Bearer token headers
- Socket.IO client using JWT handshake auth
- Service catalog loading from `GET /api/services`
- Nearby provider loading from `GET /api/customer/providers/nearby`
- Booking creation through `POST /api/customer/bookings`
- Booking room join after booking creation
- Realtime UI updates for `provider.joined`, `booking.matched`, `booking.expired`, and `provider.location.updated`

Run with custom endpoints:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api --dart-define=SOCKET_BASE_URL=http://10.0.2.2:3000
```

## Provider App

The provider Flutter app now includes:

- Demo OTP login against `POST /api/auth/verify-otp`
- JWT storage in Riverpod state for the current runtime session
- API client with Bearer token headers
- Socket.IO client using JWT handshake auth
- Online/offline API calls
- REST and realtime location update calls
- Open booking loading from `GET /api/provider/bookings/open`
- Join booking through `POST /api/provider/bookings/:id/join`
- Accept/reject participation through `POST /api/provider/bookings/:id/accept` and `POST /api/provider/bookings/:id/reject`
- Request screen state for online status, open job refresh, joined jobs, and customer-selection waiting state
- Socket listeners for `booking.opened`, `booking.matched`, and `booking.expired`

## Realtime MVP Behavior

- Provider sockets join a shared `providers:online` room after JWT authentication.
- When a booking opens, the backend emits `booking.opened` to the booking room and the provider broadcast room.
- Customer app refreshes the active booking when a provider joins or the booking status changes.
- Provider app refreshes open jobs when a new booking opens or a matching job changes state.

## Current Limitations

- Tokens are runtime-only and not persisted securely yet.
- UI is intentionally MVP-plain and close to the reference flow hierarchy, not final branding.
- Google Maps rendering is not wired yet.
- Push notification token registration now runs after login and reports setup state in the app UI, but real Firebase project files and production FCM credentials still need to be provided.
- `flutter pub get`, `flutter analyze`, and widget smoke tests pass for both customer and provider apps in the local Windows environment.
- Android platform folders are generated for both Flutter apps.
- Customer and Provider apps have been build-installed-launched on `emulator-5554` from an ASCII-only path.
- Windows Android builds should run from an ASCII-only path such as `C:\dev\massage-on-demand-vn`; the original workspace path contains Korean characters and can trigger Android/Flutter toolchain failures.

## Firebase Android Setup

Customer app:

- package/applicationId: `com.massagevn.customer.customer_app`
- place Firebase config at `apps/customer_app/android/app/google-services.json`

Provider app:

- package/applicationId: `com.massagevn.provider.provider_app`
- place Firebase config at `apps/provider_app/android/app/google-services.json`

Verification command:

```powershell
node infra/scripts/check-mobile-firebase.mjs
```

This command is also included in `powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices`.
