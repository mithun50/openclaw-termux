#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

INSTALLER_FILE="$PROJECT_DIR/lib/installer.js"
CONSTANTS_FILE="$PROJECT_DIR/flutter_app/lib/constants.dart"

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <https://.../openclaw-xxx.tgz>"
  exit 1
fi

TGZ_URL="$1"

if [[ ! "$TGZ_URL" =~ ^https?://.*\.tgz([?#].*)?$ ]]; then
  echo "Error: URL must start with http/https and end with .tgz"
  exit 1
fi

if [ ! -f "$INSTALLER_FILE" ] || [ ! -f "$CONSTANTS_FILE" ]; then
  echo "Error: target files not found."
  exit 1
fi

python3 - "$INSTALLER_FILE" "$CONSTANTS_FILE" "$TGZ_URL" <<'PY'
import re
import sys

installer_path, constants_path, url = sys.argv[1], sys.argv[2], sys.argv[3]

installer = open(installer_path, "r", encoding="utf-8").read()
constants = open(constants_path, "r", encoding="utf-8").read()

installer_new, n1 = re.subn(
    r"(const OPENCLAW_TGZ_URL\s*=\s*')[^']+(';)",
    rf"\1{url}\2",
    installer,
    count=1,
)
if n1 != 1:
    print("Error: failed to update OPENCLAW_TGZ_URL in lib/installer.js")
    sys.exit(2)

constants_new, n2 = re.subn(
    r"(static const String openclawTgzUrl\s*=\s*[\r\n]+\s*')[^']+(';)",
    rf"\1{url}\2",
    constants,
    count=1,
)
if n2 != 1:
    print("Error: failed to update openclawTgzUrl in flutter_app/lib/constants.dart")
    sys.exit(3)

open(installer_path, "w", encoding="utf-8").write(installer_new)
open(constants_path, "w", encoding="utf-8").write(constants_new)

print("Updated:")
print(f" - {installer_path}")
print(f" - {constants_path}")
print(f"New URL: {url}")
PY

