#!/usr/bin/env bash
# Compila e empacota build/Goals.app. Use --install para copiar para /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/Goals.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Goals "$APP/Contents/MacOS/Goals"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Goals 2>/dev/null || true
  rm -rf /Applications/Goals.app
  cp -R "$APP" /Applications/Goals.app
  echo "Instalado em /Applications/Goals.app"
else
  echo "Pronto: $APP"
fi
