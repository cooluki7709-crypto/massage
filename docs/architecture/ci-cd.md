# CI/CD Preparation

GitHub Actions is configured in `.github/workflows/ci.yml`.

## Current Checks

- Install dependencies with `npm ci`.
- Validate Prisma schema.
- Generate Prisma Client.
- Typecheck API.
- Typecheck Admin Web.
- Build API.
- Build Admin Web.
- Syntax-check seed and E2E smoke scripts.

## Deferred Checks

Flutter checks pass locally, but remain deferred in GitHub Actions until the CI image installs Flutter and Android tooling. When ready, add:

```yaml
- uses: subosito/flutter-action@v2
  with:
    flutter-version: stable
- run: flutter analyze
  working-directory: apps/customer_app
- run: flutter analyze
  working-directory: apps/provider_app
```

## Deployment Shape

The Admin Web typecheck runs `next typegen` before `tsc --noEmit` because Next.js 16 adds generated route types under `.next/types`.

The project is still VPS-friendly:

- Build API and Admin Web from GitHub.
- Run Postgres/PostGIS, Redis, and S3/R2-compatible storage outside the app process.
- Inject secrets through environment variables.
- Keep migrations explicit and reviewed before production deploys.
