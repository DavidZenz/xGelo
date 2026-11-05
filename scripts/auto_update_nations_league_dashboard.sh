#!/usr/bin/env bash
# Compatibility entrypoint: all non-WC routes now refresh as one validated batch.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec /bin/bash "$ROOT_DIR/scripts/auto_update_competition_dashboards.sh" "$@"
