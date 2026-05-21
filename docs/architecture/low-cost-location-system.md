# Low-Cost Location System

HANDS now avoids Google Maps Directions, routing APIs, and realtime location streaming for MVP cost control.

## Runtime Flow

Customer app:
- Loads MapTiler only on map screens.
- Requests GPS once when choosing a service location.
- Shows a fixed center pin over the MapLibre map.
- Lets the customer search Vietnam addresses through Geoapify.
- Debounces Geoapify calls by 500 ms and caches repeated queries in memory.
- Saves `latitude`, `longitude`, and `address_text` before booking.
- Loads nearby providers from the HANDS API using the selected/customer coordinate.

Provider app:
- Requests GPS when the provider logs in and goes online.
- Sends one location update immediately.
- Sends another update every 10 minutes while the app is open.
- Does not run background tracking when the app is closed.
- Keeps the last stored provider location available to customers.

Backend:
- Stores `ProviderProfile.currentLat`, `currentLng`, and `currentLocationUpdatedAt`.
- Stores customer-confirmed pins in `CustomerSelectedLocation`.
- Filters nearby providers with a 5 km default radius.
- Marks locations older than 30 minutes as not recent.
- Hides provider locations older than 24 hours from discovery.

## Environment Variables

```dotenv
MAPTILER_API_KEY=
GEOAPIFY_API_KEY=
SUPABASE_URL=
SUPABASE_ANON_KEY=
PROVIDER_SEARCH_RADIUS_METERS=5000
PROVIDER_STALE_AFTER_MINUTES=30
PROVIDER_HIDE_AFTER_HOURS=24
```

Flutter local run:

```powershell
$env:MAPTILER_API_KEY="your-maptiler-key"
$env:GEOAPIFY_API_KEY="your-geoapify-key"
powershell -ExecutionPolicy Bypass -File C:\dev\massage-vn-workspace\repo\infra\scripts\run-hands-emulator.ps1 -App customer
```

## Supabase SQL

Use [location-schema.sql](/C:/dev/massage-vn-workspace/repo/infra/supabase/location-schema.sql) if HANDS later stores map/location data directly in Supabase.

The current MVP implementation uses the existing NestJS API and PostgreSQL/PostGIS-compatible schema so mobile apps do not need direct Supabase access yet.

## Cost Controls

- No Directions API.
- No Routing API.
- No WebSocket GPS streaming.
- No background location updates.
- Provider app updates location every 10 minutes only while open.
- Nearby provider search hides old locations instead of polling continuously.
- Geoapify search runs only after 500 ms debounce and reuses cached results.
