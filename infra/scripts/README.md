# Scripts

Operational scripts:

- `api-smoke.mjs` runs the end-to-end MVP API flow against a running API.
- `check-env.mjs` validates required and recommended environment variables.
- `deploy-prod.ps1` runs the production-style Docker flow on Windows PowerShell.
- `deploy-prod.sh` runs the production-style Docker flow on Linux/macOS shells.
- `backup-db.ps1` and `backup-db.sh` create PostgreSQL backups under `backups/`.
- `restore-db.ps1` and `restore-db.sh` restore a backup only with an explicit force flag.
- `collect-logs.ps1` and `collect-logs.sh` collect Docker Compose service logs under `logs/`.

The deploy scripts validate env, start `docker-compose.prod.yml`, run Prisma migrations, optionally seed demo data, and optionally run the smoke script.
