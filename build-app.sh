#!/bin/bash
#
# build-app.sh — 编译 JianPin.app
# 用法: ./build-app.sh
#
# 将 JianPinEngine 和 JianPin 编译为 macOS .app  bundle
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_NAME="简拼通讯录"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 编译 JianPinEngine + JianPin (release)..."
cd "$PROJECT_DIR"
swift build -c release --product JianPin

echo "==> 创建 .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/JianPin" "$MACOS_DIR/"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/"
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/"
fi

echo "==> 代码签名（可选，不签名也可运行）..."
codesign --force --deep --sign - "$MACOS_DIR/JianPin" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo ""
echo "======================================"
echo "  ✅ 构建完成: $APP_DIR"
echo "  将 $APP_NAME.app 拖到 Applications 即可"
echo "======================================"