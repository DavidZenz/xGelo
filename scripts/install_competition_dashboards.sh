#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PYTHON_SCRIPT="${XGELO_PYTHON:-$(command -v python3 2>/dev/null || true)}"
[[ -x "$PYTHON_SCRIPT" ]] || { echo "Python3 is required for scheduler installation." >&2; exit 1; }
exec "$PYTHON_SCRIPT" "$ROOT_DIR/scripts/install_competition_scheduler.py" "$@"
