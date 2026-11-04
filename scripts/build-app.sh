#!/usr/bin/env bash
# Build a runnable, ad-hoc-signed iPomo.app from the Swift package.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/iPomo.app"
CONFIG="${1:-release}"
VERSION="${IPOMO_VERSION:-1.0.0}"
BUILD="${IPOMO_BUILD:-1}"

cd "$ROOT"
BUILD_ARGS=(-c "$CONFIG" --product iPomo)
if [[ -n "${IPOMO_ARCHS:-}" ]]; then
    for arch in $IPOMO_ARCHS; do
        BUILD_ARGS+=(--arch "$arch")
    done
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/iPomo" "$APP/Contents/MacOS/iPomo"
chmod +x "$APP/Contents/MacOS/iPomo"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>iPomo</string>
    <key>CFBundleDisplayName</key>
    <string>iPomo</string>
    <key>CFBundleIdentifier</key>
    <string>com.ipomo.app</string>
    <key>CFBundleExecutable</key>
    <string>iPomo</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>iPomo — local-first planning timer</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc signing gives the bundle a stable identity, which macOS uses for
# notification permissions and local app behaviour.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "Built $APP"
