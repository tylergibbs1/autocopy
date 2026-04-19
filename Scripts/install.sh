#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="AutoCopy"
APP="$ROOT/${APP_NAME}.app"
DEST="/Applications/${APP_NAME}.app"

"$ROOT/Scripts/package_app.sh" release

osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true

rm -rf "$DEST"
ditto "$APP" "$DEST"

open "$DEST"

echo "Installed ${DEST}"
