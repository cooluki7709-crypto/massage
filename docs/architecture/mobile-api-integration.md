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
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api --dart-define=SOCKET_BASE_URL=http://localhost:3000
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

## Current Limitations

- Tokens are runtime-only and not persisted securely yet.
- UI is intentionally MVP-plain and close to the reference flow hierarchy, not final branding.
- Google Maps rendering is not wired yet.
- Push notification token registration exists at the API/client layer, but real FCM delivery credentials are not configured yet.
- `flutter pub get` and `flutter analyze` pass for both customer and provider apps in the local Windows environment.
- Device/emulator runs still need Android Studio or a physical Android device.
