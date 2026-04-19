#!/usr/bin/env bash
set -euo pipefail

CONF="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source "$ROOT/version.env"

APP_NAME="AutoCopy"
BUNDLE_ID="${AUTOCOPY_BUNDLE_ID:-com.tylergibbs.autocopy}"
APP="$ROOT/${APP_NAME}.app"

SWIFTC_FLAGS=(-parse-as-library)
case "$CONF" in
  release) SWIFTC_FLAGS+=(-O) ;;
  debug)   SWIFTC_FLAGS+=(-Onone -g) ;;
  *) echo "ERROR: unknown configuration '$CONF' (use release|debug)" >&2; exit 1 ;;
esac

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc "${SWIFTC_FLAGS[@]}" "$ROOT/autocopy.swift" \
  -o "$APP/Contents/MacOS/${APP_NAME}"

BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>MIT License.</string>
    <key>AutoCopyBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>AutoCopyGitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

if [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

xattr -cr "$APP"
find "$APP" -name '._*' -delete
codesign --force --sign - "$APP"

echo "Created $APP"
