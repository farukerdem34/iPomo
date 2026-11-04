#!/usr/bin/env bash
# Package dist/iPomo.app into a compressed DMG with a styled install window.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/iPomo.app"
DMG="${1:-$ROOT/dist/iPomo.dmg}"

if [[ ! -d "$APP" ]]; then
    echo "error: $APP not found; run ./scripts/build-app.sh release first" >&2
    exit 1
fi

mkdir -p "$(dirname "$DMG")"
WORK="$(mktemp -d "$ROOT/dist/dmg.XXXXXX")"
STAGE="$WORK/stage"
MOUNT="$WORK/mount"
RW="$WORK/iPomo-rw.dmg"
mkdir -p "$STAGE" "$MOUNT"

cleanup() {
    hdiutil detach -quiet -force "$MOUNT" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

cp -R "$APP" "$STAGE/iPomo.app"
ln -s /Applications "$STAGE/Applications"

# Warm Editorial window background, supplied as a HiDPI TIFF for Finder.
mkdir -p "$STAGE/.background"
swift "$ROOT/scripts/make-dmg-background.swift" "$STAGE/.background" >/dev/null
tiffutil -cathidpicheck \
    "$STAGE/.background/background.png" \
    "$STAGE/.background/background@2x.png" \
    -out "$STAGE/.background/background.tiff" >/dev/null 2>&1
rm -f "$STAGE/.background/background.png" "$STAGE/.background/background@2x.png"

rm -f "$DMG"
# A temporary volume name keeps Finder from confusing this image with an
# already-mounted "iPomo" disk; it is renamed back before the image is saved.
VOLUME="iPomo Setup ${WORK##*.}"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGE" -ov -format UDRW "$RW"
hdiutil attach -quiet -nobrowse -noautoopen -mountpoint "$MOUNT" "$RW"

# Finder records the window size, icon positions, and background in .DS_Store.
# The mounted folder is addressed by path, so another mounted "iPomo" volume
# cannot capture the layout.
cat > "$WORK/layout.applescript" <<APPLESCRIPT
tell application "Finder"
    set targetFolder to (POSIX file "$MOUNT") as alias
    open targetFolder
    set containerWindow to container window of targetFolder
    set current view of containerWindow to icon view
    set toolbar visible of containerWindow to false
    set statusbar visible of containerWindow to false
    try
        set pathbar visible of containerWindow to false
    end try
    try
        set sidebar width of containerWindow to 0
    end try
    set the bounds of containerWindow to {400, 140, 1060, 588}
    set viewOptions to the icon view options of containerWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set background picture of viewOptions to (POSIX file "$MOUNT/.background/background.tiff")
    set position of item "iPomo.app" of containerWindow to {165, 210}
    set position of item "Applications" of containerWindow to {495, 210}
    delay 2
    close containerWindow
end tell
APPLESCRIPT

if osascript "$WORK/layout.applescript" >/dev/null 2>"$WORK/layout.err"; then
    for _ in {1..10}; do
        if [[ -f "$MOUNT/.DS_Store" ]]; then break; fi
        sleep 0.5
    done
else
    # Finder scripting can be blocked by automation permissions; the DMG is
    # still installable, just without the custom layout.
    echo "warning: could not style the DMG window; building a plain layout" >&2
    cat "$WORK/layout.err" >&2 || true
fi

if [[ ! -f "$MOUNT/.DS_Store" ]]; then
    echo "warning: Finder did not write a window layout; the DMG will use default icons" >&2
    if [[ -n "${CI:-}" ]]; then
        echo "error: failing instead of publishing an unstyled DMG" >&2
        exit 1
    fi
fi

diskutil rename "$MOUNT" "iPomo" >/dev/null
sync

if ! hdiutil detach -quiet "$MOUNT"; then
    sleep 2
    hdiutil detach -quiet -force "$MOUNT"
fi

hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"

(
    cd "$(dirname "$DMG")"
    shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256"
)

echo "Built $DMG"
