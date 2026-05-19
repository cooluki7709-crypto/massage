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

## Current Limitations

- Tokens are runtime-only and not persisted securely yet.
- UI is intentionally MVP-plain and close to the reference flow hierarchy, not final branding.
- Google Maps rendering is not wired yet.
- Push notification token registration exists at the API/client layer, but real FCM delivery credentials are not configured yet.
- `flutter pub get`, `flutter analyze`, and widget smoke tests pass for both customer and provider apps in the local Windows environment.
- Android platform folders are generated for both Flutter apps.
- Customer and Provider apps have been build-installed-launched on `emulator-5554` from an ASCII-only path.
- Windows Android builds should run from an ASCII-only path such as `C:\dev\massage-on-demand-vn`; the original workspace path contains Korean characters and can trigger Android/Flutter toolchain failures.
