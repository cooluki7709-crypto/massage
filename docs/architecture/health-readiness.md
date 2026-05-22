# Health And Readiness

The API exposes two public operational checks:

- `GET /api/health` confirms the Nest app is running.
- `GET /api/health/ready` checks database, Redis, and storage configuration readiness.
- `GET /api/health/external` checks external account/API-key readiness without exposing secret values.

## Readiness Checks

- `database`: runs `SELECT 1` through Prisma.
- `redis`: sends `PING` through the Redis state service.
- `storage`: verifies S3-compatible environment variables are configured for MinIO, Cloudflare R2, or Supabase Storage S3.

Storage can be in `placeholder` mode for local MVP flows. Readiness only fails for database or Redis failures because placeholder storage is intentionally supported for development.

## Usage

```powershell
Invoke-RestMethod http://localhost:3100/api/health
Invoke-RestMethod http://localhost:3100/api/health/ready
Invoke-RestMethod http://localhost:3100/api/health/external
```

The E2E smoke script calls both checks before exercising product flows.
