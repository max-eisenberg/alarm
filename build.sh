#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/.build"
MODULE_CACHE="$BUILD_DIR/ModuleCache"
SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk"
OUTPUT="$PROJECT_DIR/alarm"

rm -rf "$MODULE_CACHE"
mkdir -p "$BUILD_DIR" "$MODULE_CACHE"

swiftc \
  -parse-as-library \
  -O \
  -whole-module-optimization \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE" \
  -target arm64-apple-macos13.0 \
  "$PROJECT_DIR"/Sources/*.swift \
  -framework AppKit \
  -framework SwiftUI \
  -framework LocalAuthentication \
  -framework IOKit \
  -framework CoreAudio \
  -framework AudioToolbox \
  -framework AVFoundation \
  -o "$OUTPUT"

codesign --force --sign - --identifier com.donttouchmylaptop.alarm "$OUTPUT"
chmod +x "$OUTPUT"

echo "Built: $OUTPUT"
echo "Run:   ./alarm"
