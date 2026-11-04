#!/usr/bin/env bash
# Build, launch, and verify that iPomo creates a window and a menu-bar item.
# This script stops any running iPomo instance and leaves the app open.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_DIR="$HOME/Library/Logs/DiagnosticReports"
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT

"$ROOT/scripts/build-app.sh" release

pkill -x iPomo 2>/dev/null || true
open "$ROOT/dist/iPomo.app"

for _ in {1..40}; do
    if pgrep -x iPomo >/dev/null; then break; fi
    sleep 0.25
done

if ! pgrep -x iPomo >/dev/null; then
    echo "FAIL: iPomo did not start" >&2
    exit 1
fi

sleep 1
swift "$ROOT/scripts/check-window.swift"

CRASH_REPORT="$(find "$REPORT_DIR" -maxdepth 1 -name 'iPomo*' -newer "$MARKER" -print -quit 2>/dev/null || true)"
if [[ -n "$CRASH_REPORT" ]]; then
    echo "FAIL: a new iPomo crash report exists: $CRASH_REPORT" >&2
    exit 1
fi

echo "Smoke check passed."
