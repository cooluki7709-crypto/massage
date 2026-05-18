# Observability

The MVP includes basic operational diagnostics for Docker Compose deployments.

## Health

- `GET /api/health`
- `GET /api/health/ready`

Readiness checks database, Redis, and storage configuration.

## Log Collection

PowerShell:

```powershell
.\infra\scripts\collect-logs.ps1
```

Shell:

```bash
sh infra/scripts/collect-logs.sh
```

By default, logs from the last two hours are collected for:

- `api`
- `admin_web`
- `nginx`
- `postgres`
- `redis`
- `minio`
- `minio-init`

Output is written under `logs/diagnostics-YYYYMMDD-HHMMSS/` and ignored by Git.

## Request IDs

The API adds or forwards `x-request-id` for every HTTP request.

- If the client sends `x-request-id`, the API preserves it.
- Otherwise the API generates a UUID.
- The response exposes `x-request-id`.
- Structured JSON request logs include `requestId`, method, path, status code, and duration.
- Error responses include `requestId`, path, timestamp, and status code.

Nginx forwards its `$request_id` to API and Admin Web upstreams.

## Security Headers And Rate Limit Signals

The API sets basic security headers:

- `x-content-type-options`
- `x-frame-options`
- `referrer-policy`
- `permissions-policy`
- `content-security-policy`
- `strict-transport-security` in production

Auth endpoints return rate-limit headers:

- `x-ratelimit-limit`
- `x-ratelimit-remaining`
- `x-ratelimit-reset`
- `retry-after` on `429`

## Production Next Steps

- Move auth rate limiting to Redis or a gateway if multiple API replicas are used.
- Forward logs to a managed provider before scaling beyond a single VPS.
- Add uptime checks against `/api/health/ready`.
