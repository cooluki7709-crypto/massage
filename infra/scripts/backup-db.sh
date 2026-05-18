#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
OUTPUT_DIR="${OUTPUT_DIR:-backups}"

command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed or not available on PATH." >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_PATH="$OUTPUT_DIR/massage-vn-$TIMESTAMP.dump"

echo "Creating database backup at $OUTPUT_PATH"
docker compose -f "$COMPOSE_FILE" exec -T postgres pg_dump -U massage -d massage_vn -Fc > "$OUTPUT_PATH"
echo "Backup completed: $OUTPUT_PATH"
