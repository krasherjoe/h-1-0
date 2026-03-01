#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-debug}"

case "${BUILD_MODE}" in
  debug|profile|release)
    ;;
  *)
    echo "Usage: $0 [debug|profile|release]" >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DART_DEFINE="APP_BUILD_TIMESTAMP=${timestamp}"

echo "[build_with_expiry] Using timestamp: ${timestamp} (UTC)"
echo "[build_with_expiry] Running flutter analyze..."
flutter analyze

echo "[build_with_expiry] Building APK (${BUILD_MODE})..."
case "${BUILD_MODE}" in
  debug)
    flutter build apk --debug --dart-define="${DART_DEFINE}"
    ;;
  profile)
    flutter build apk --profile --dart-define="${DART_DEFINE}"
    ;;
  release)
    flutter build apk --release --dart-define="${DART_DEFINE}"
    ;;
esac

echo "[build_with_expiry] Done. APK with 90-day lifespan generated."
