# Docker

Docker Compose runs PostgreSQL/PostGIS, Redis, and MinIO for local development.

Production-style app images:

- `api.Dockerfile` builds and runs the NestJS API workspace.
- `admin_web.Dockerfile` builds and runs the Next.js admin workspace.

Use from the repository root:

```powershell
docker compose -f docker-compose.prod.yml up -d --build
```

Run migrations after services are healthy:

```powershell
docker compose -f docker-compose.prod.yml exec api npx prisma migrate deploy --schema apps/api/prisma/schema.prisma
```
