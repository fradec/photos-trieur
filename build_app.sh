#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

APP_NAME="launch_sorter.app"

osacompile -o "$APP_NAME" launch_sorter.applescript
/bin/cp -f photo_sorter.py "$APP_NAME/Contents/Resources/photo_sorter.py"
codesign --force --deep -s - "$APP_NAME"

echo "Build termine: $APP_NAME"
