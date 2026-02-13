#!/bin/bash
# Build the OpenClaw Flutter APK
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
FLUTTER_DIR="$PROJECT_DIR/flutter_app"

echo "=== OpenClaw APK Build ==="
echo ""

# Step 1: Fetch proot binaries if not present
if [ ! -f "$FLUTTER_DIR/android/app/jniLibs/arm64-v8a/libproot.so" ]; then
    echo "[1/3] Fetching PRoot binaries..."
    bash "$SCRIPT_DIR/fetch-proot-binaries.sh"
else
    echo "[1/3] PRoot binaries already present"
fi
echo ""

# Step 2: Get Flutter dependencies
echo "[2/3] Getting Flutter dependencies..."
cd "$FLUTTER_DIR"
flutter pub get
echo ""

# Step 3: Build APK
echo "[3/3] Building release APK..."
flutter build apk --release
echo ""

APK_PATH="$FLUTTER_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo "=== Build Successful ==="
    echo "APK: $APK_PATH"
    echo "Size: $(du -h "$APK_PATH" | cut -f1)"
    echo ""
    echo "Install: adb install $APK_PATH"
else
    echo "=== Build Failed ==="
    exit 1
fi
