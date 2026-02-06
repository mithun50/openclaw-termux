#!/bin/bash
# Fetch pre-compiled PRoot binaries for Android
# Places them in jniLibs/<abi>/libproot.so so Android auto-extracts
# them to nativeLibraryDir with execute permission (bypasses W^X).
#
# Source: https://github.com/proot-me/proot/releases
# Fallback: build from Termux packages or use bundled static builds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JNILIBS_DIR="$SCRIPT_DIR/../flutter_app/android/app/jniLibs"
TMP_DIR=$(mktemp -d)

trap 'rm -rf "$TMP_DIR"' EXIT

# Use Termux's pre-built proot packages (most reliable for Android)
TERMUX_PKG_BASE="https://packages.termux.dev/apt/termux-main/pool/main/p/proot"

fetch_from_termux_pkg() {
    local arch="$1"
    local deb_arch="$2"
    local out_dir="$JNILIBS_DIR/$arch"

    mkdir -p "$out_dir"

    echo "  [$arch] Fetching package list..."

    # Download the package index to find the latest proot deb
    local pkg_url
    pkg_url=$(curl -fsSL "https://packages.termux.dev/apt/termux-main/dists/stable/main/binary-${deb_arch}/Packages" \
        | grep -A 20 "^Package: proot$" \
        | grep "^Filename:" \
        | head -1 \
        | awk '{print $2}')

    if [ -z "$pkg_url" ]; then
        echo "  [$arch] WARN: Could not find proot in Termux repo, using fallback build method"
        return 1
    fi

    local full_url="https://packages.termux.dev/apt/termux-main/${pkg_url}"
    local deb_file="$TMP_DIR/proot-${arch}.deb"

    echo "  [$arch] Downloading ${full_url}..."
    curl -fsSL "$full_url" -o "$deb_file"

    # Extract proot binary from the deb
    local extract_dir="$TMP_DIR/extract-${arch}"
    mkdir -p "$extract_dir"
    cd "$extract_dir"
    ar x "$deb_file"
    tar xf data.tar.* 2>/dev/null || tar xf data.tar.xz 2>/dev/null || tar xf data.tar.gz 2>/dev/null
    cd "$SCRIPT_DIR"

    local proot_bin
    proot_bin=$(find "$extract_dir" -name "proot" -type f | head -1)

    if [ -z "$proot_bin" ]; then
        echo "  [$arch] ERROR: proot binary not found in package"
        return 1
    fi

    cp "$proot_bin" "$out_dir/libproot.so"
    chmod 755 "$out_dir/libproot.so"
    echo "  [$arch] OK ($(du -h "$out_dir/libproot.so" | cut -f1))"
}

# Fallback: download static proot builds from a known source
fetch_static_build() {
    local arch="$1"
    local binary_name="$2"
    local out_dir="$JNILIBS_DIR/$arch"

    mkdir -p "$out_dir"

    # Use proot-me releases as fallback
    local url="https://github.com/proot-me/proot/releases/latest/download/${binary_name}"
    echo "  [$arch] Trying static build from proot-me..."

    if curl -fsSL "$url" -o "$out_dir/libproot.so" 2>/dev/null; then
        chmod 755 "$out_dir/libproot.so"
        echo "  [$arch] OK ($(du -h "$out_dir/libproot.so" | cut -f1))"
        return 0
    fi

    echo "  [$arch] WARN: Static build not available"
    return 1
}

echo "=== Fetching PRoot binaries for Android ==="
echo ""

SUCCESS=0
FAILED=0

for entry in "arm64-v8a:aarch64:proot-aarch64" "armeabi-v7a:arm:proot-arm" "x86_64:x86_64:proot-x86_64"; do
    IFS=':' read -r abi deb_arch static_name <<< "$entry"
    echo "[$abi]"

    if fetch_from_termux_pkg "$abi" "$deb_arch" 2>/dev/null; then
        SUCCESS=$((SUCCESS + 1))
    elif fetch_static_build "$abi" "$static_name" 2>/dev/null; then
        SUCCESS=$((SUCCESS + 1))
    else
        echo "  [$abi] FAILED: Could not obtain proot binary"
        # Create a placeholder so the build doesn't fail
        # The app will show an error at runtime on this arch
        mkdir -p "$JNILIBS_DIR/$abi"
        echo "PLACEHOLDER" > "$JNILIBS_DIR/$abi/libproot.so"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo "=== Summary ==="
echo "Success: $SUCCESS / 3"
if [ "$FAILED" -gt 0 ]; then
    echo "Failed: $FAILED (placeholder files created)"
    echo ""
    echo "To fix: manually place working proot binaries at:"
    for abi in arm64-v8a armeabi-v7a x86_64; do
        echo "  $JNILIBS_DIR/$abi/libproot.so"
    done
    # Don't exit with error — let the build proceed for architectures that worked
fi

echo ""
echo "Files:"
ls -la "$JNILIBS_DIR"/*/libproot.so 2>/dev/null || echo "  (none)"
