#!/usr/bin/env bash
# Package dist/iPomo.app into a compressed DMG with an Applications shortcut.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/iPomo.app"
DMG="${1:-$ROOT/dist/iPomo.dmg}"

if [[ ! -d "$APP" ]]; then
    echo "error: $APP not found; run ./scripts/build-app.sh release first" >&2
    exit 1
fi

STAGE="$(mktemp -d "$ROOT/dist/dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/iPomo.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil create -quiet -volname "iPomo" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

(
    cd "$(dirname "$DMG")"
    shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)

echo "Built $DMG"
