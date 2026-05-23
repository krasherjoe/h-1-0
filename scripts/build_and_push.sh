#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-release}"

cd "${PROJECT_ROOT}"

echo "=== Step 1: Build APK (${BUILD_MODE}) ==="
bash scripts/build_with_expiry.sh "${BUILD_MODE}"

echo ""
echo "=== Step 2: Install on device ==="
APK_PATH="build/app/outputs/flutter-apk/app-${BUILD_MODE}.apk"
if [ ! -f "${APK_PATH}" ]; then
  echo "Error: APK not found at ${APK_PATH}" >&2
  exit 1
fi

adb install -r "${APK_PATH}"

echo ""
echo "=== Done ==="
echo "APK installed: ${APK_PATH}"

# Launch app
PACKAGE_NAME="com.example.h_1"
adb shell monkey -p "${PACKAGE_NAME}" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 || true
echo "App launched."
