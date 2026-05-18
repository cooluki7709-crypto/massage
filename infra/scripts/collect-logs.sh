#!/usr/bin/env sh
set -eu

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
OUTPUT_DIR="${OUTPUT_DIR:-logs}"
SINCE="${SINCE:-2h}"
SERVICES="${SERVICES:-api admin_web nginx postgres redis minio minio-init}"

command -v docker >/dev/null 2>&1 || {
  echo "Docker is not installed or not available on PATH." >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE_DIR="$OUTPUT_DIR/diagnostics-$TIMESTAMP"
mkdir -p "$BUNDLE_DIR"

echo "Collecting compose status"
docker compose -f "$COMPOSE_FILE" ps > "$BUNDLE_DIR/compose-ps.txt"

for service in $SERVICES; do
  echo "Collecting logs for $service"
  docker compose -f "$COMPOSE_FILE" logs --since "$SINCE" --no-color "$service" > "$BUNDLE_DIR/$service.log"
done

echo "Diagnostics collected: $BUNDLE_DIR"
