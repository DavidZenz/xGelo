#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PYTHON_SCRIPT="${XGELO_PYTHON:-}"
if [[ -z "$PYTHON_SCRIPT" ]]; then
  PYTHON_SCRIPT="$(command -v python3 2>/dev/null || true)"
  if [[ ! -x "$PYTHON_SCRIPT" ]]; then
    for candidate in /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
      if [[ -x "$candidate" ]]; then PYTHON_SCRIPT="$candidate"; break; fi
    done
  fi
fi
[[ -x "$PYTHON_SCRIPT" ]] || { echo "Python3 is required; set XGELO_PYTHON to an executable." >&2; exit 1; }
exec "$PYTHON_SCRIPT" "$ROOT_DIR/scripts/competition_refresh.py" "$@"
