#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="gui/$(id -u)"
LEGACY="com.xgelo.dashboard-update"
CURRENT="com.xgelo.competition-dashboards"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/$CURRENT.plist"

mkdir -p "$PLIST_DIR"
cp "$ROOT_DIR/scripts/$CURRENT.plist" "$PLIST"

# bootout is intentionally best effort for a label that may not be loaded;
# disable must succeed so a stale legacy agent cannot be reactivated.
launchctl bootout "$DOMAIN/$LEGACY" 2>/dev/null || true
launchctl disable "$DOMAIN/$LEGACY"
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl print "$DOMAIN/$CURRENT" >/dev/null
launchctl print-disabled "$DOMAIN" | grep -Fq "$LEGACY"

echo "Installed $CURRENT and disabled $LEGACY in $DOMAIN."
