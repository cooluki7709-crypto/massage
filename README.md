# Massage On-Demand Vietnam MVP

Original MVP for a realtime on-demand massage marketplace in Vietnam.

## Apps

- `apps/customer_app` - Flutter customer app.
- `apps/provider_app` - Flutter provider app.
- `apps/admin_web` - Next.js admin dashboard.
- `apps/api` - NestJS API, realtime gateway, matching, payments, jobs.

## Packages

- `packages/shared-types` - Cross-app domain enums and DTO contracts.
- `packages/shared-ui` - Placeholder for future shared web UI conventions.
- `packages/config` - Shared lint/format/config presets.

## Infrastructure

- PostgreSQL + PostGIS
- Redis for realtime session state and queues
- S3-compatible storage or Cloudflare R2
- Nginx reverse proxy

## Development

```powershell
cd massage-on-demand-vn
npm install
npm run lint
npm run typecheck
docker compose up -d
```

Local storage uses MinIO. The compose file creates the `massage-vn` bucket automatically; `.env.example` points S3-compatible settings at that local bucket.

Seed and smoke test after Docker is running:

```powershell
$env:DATABASE_URL='postgresql://massage:massage@localhost:5432/massage_vn?schema=public'
npm run prisma:migrate --workspace @massage-vn/api
npm run prisma:seed --workspace @massage-vn/api
npm run dev --workspace @massage-vn/api
node infra/scripts/api-smoke.mjs
```

Health checks:

```powershell
Invoke-RestMethod http://localhost:3000/api/health
Invoke-RestMethod http://localhost:3000/api/health/ready
```

Environment check:

```powershell
node infra/scripts/check-env.mjs .env.example
```

Development tool check:

```powershell
.\infra\scripts\check-dev-env.ps1
```

If PowerShell execution policy blocks local scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\check-dev-env.ps1
```

Full local verification:

```powershell
npm run verify:local
```

After Docker Desktop is installed and running:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\verify-local.ps1 -WithServices
```

If Git, Docker, or Flutter are missing, open PowerShell as Administrator and run:

```powershell
.\infra\scripts\check-dev-env.ps1 -Install
```

Dedicated installer for Git, Docker Desktop, and Flutter:

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\scripts\install-dev-tools-admin.ps1
```

The smoke script covers demo OTP login, provider verification file presign/read-url, admin verification approval, booking creation, provider join, customer selection, chat, completion, review/tip, provider earnings, payout batch creation, admin refund, and notification reads.

This repository is structured for small, commit-ready phases. Phase 1 includes reports, architecture docs, Docker, Prisma schema, backend skeleton, and starter mobile/admin UI.

## Mobile MVP

Customer and provider apps now have runtime API clients, demo OTP login, Bearer-token REST calls, and Socket.IO JWT handshake setup. See:

- `docs/architecture/mobile-api-integration.md`

## Admin MVP

Admin Web now reads protected admin APIs from server components and falls back to empty states when the API is unavailable. See:

- `docs/architecture/admin-web-integration.md`

## Payments MVP

MoMo, VNPay, and Cash are wired behind placeholder adapters with callback routes and status-check jobs. See:

- `docs/architecture/payments.md`

## Reviews MVP

Completed bookings can be reviewed by customers. Provider ratings are recalculated from published reviews. See:

- `docs/architecture/reviews.md`

## CI

GitHub Actions checks Prisma, API, Admin Web, and script syntax on `main`, `develop`, and pull requests. See:

- `docs/architecture/ci-cd.md`

## Deployment

Nginx routing and environment validation notes are documented in:

- `docs/architecture/deployment.md`
- `docs/architecture/dev-environment.md`
- `docs/architecture/backup-restore.md`
- `docs/architecture/observability.md`

Production-style compose:

```powershell
docker compose -f docker-compose.prod.yml up -d --build
```

Scripted deployment flow:

```powershell
.\infra\scripts\deploy-prod.ps1
```

```bash
sh infra/scripts/deploy-prod.sh
```
