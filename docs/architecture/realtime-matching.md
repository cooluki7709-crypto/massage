# Realtime Matching Implementation

## Redis Keys

- `providers:status` - provider id to status hash.
- `provider:{providerId}:location` - latest provider location, 10 minute TTL.
- `matching:active` - set of active matching booking ids.
- `matching:{bookingId}` - active matching payload, 20 minute TTL.
- `matching:{bookingId}:participants` - providers who joined a booking.

## BullMQ Queues

- `booking-timeouts`
  - Job name: `booking-timeout`
  - Job id: `booking-timeout:{bookingId}`
  - Behavior: if the booking is still `OPEN_MATCHING`, mark it `EXPIRED`, release payment, close Redis matching state, emit `booking.expired`.

## Socket.IO Events

Emitted by REST-backed services:

- `booking.opened`
- `provider.joined`
- `booking.matched`
- `booking.expired`
- `service.completed`

Location gateway emits:

- `provider.location.updated`

## Socket Auth

Socket.IO clients must send the access token in either:

```ts
io(API_URL, { auth: { token: accessToken } });
```

or as an `Authorization: Bearer <accessToken>` handshake header. Booking and chat room joins are checked against customer ownership, provider participation/selection, or admin role.

## Auth Note

REST routes use `Authorization: Bearer <accessToken>`. The OTP endpoint returns signed dev tokens and route handlers enforce customer, provider, and admin role boundaries through guards.
