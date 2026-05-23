#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/内存压力仪.app"

cd "$ROOT"
swift "$ROOT/Scripts/generate-app-icon.swift"
iconutil -c icns "$ROOT/Packaging/AppIcon.iconset" -o "$ROOT/Packaging/AppIcon.icns"
swift build -c release

mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "$ROOT/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/.build/release/MemoryPressureCN" "$APP/Contents/MacOS/MemoryPressureCN"
chmod +x "$APP/Contents/MacOS/MemoryPressureCN"
touch "$APP"

echo "已生成：$APP"
