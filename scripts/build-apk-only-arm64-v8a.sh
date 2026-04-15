#!/bin/bash
# Build the OpenClaw Flutter APK (arm64-v8a only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
FLUTTER_DIR="$PROJECT_DIR/flutter_app"

echo "=== OpenClaw APK Build (arm64-v8a only) ==="
echo ""

# Step 1: Fetch proot binaries if not present
if [ ! -f "$FLUTTER_DIR/android/app/jniLibs/arm64-v8a/libproot.so" ]; then
    echo "[1/3] Fetching PRoot binaries (arm64-v8a only)..."
    bash "$SCRIPT_DIR/fetch-proot-binaries-only-arm64-v8a.sh"
else
    echo "[1/3] PRoot binaries already present (arm64-v8a)"
fi
echo ""

# Step 2: Get Flutter dependencies
echo "[2/3] Getting Flutter dependencies..."
cd "$FLUTTER_DIR"
flutter pub get
echo ""

# Step 3: Build APK
echo "[3/3] Building release APK (arm64-v8a)..."
flutter build apk --release --target-platform android-arm64
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
