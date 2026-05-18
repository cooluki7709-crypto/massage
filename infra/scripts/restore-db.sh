#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
BACKUP_PATH="${1:-}"
FORCE="${FORCE:-0}"

if [ "$FORCE" != "1" ]; then
  echo "Restore is destructive. Re-run with FORCE=1 and a backup path after confirming the target database." >&2
  exit 1
fi

if [ -z "$BACKUP_PATH" ] || [ ! -f "$BACKUP_PATH" ]; then
  echo "Backup file not found: $BACKUP_PATH" >&2
  exit 1
fi

command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed or not available on PATH." >&2
  exit 1
}

echo "Restoring database from $BACKUP_PATH"
docker compose -f "$COMPOSE_FILE" exec -T postgres pg_restore -U massage -d massage_vn --clean --if-exists --no-owner < "$BACKUP_PATH"
echo "Restore completed."
