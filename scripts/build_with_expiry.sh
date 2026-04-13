#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_MODE="${1:-debug}"
LIFESPAN_DAYS="${2:-90}"

case "${BUILD_MODE}" in
  debug|profile|release)
    ;;
  *)
    echo "Usage: $0 [debug|profile|release] [lifespan_days]" >&2
    echo "Example: $0 release 180" >&2
    exit 1
    ;;
esac

cd "${PROJECT_ROOT}"

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DART_DEFINE="APP_BUILD_TIMESTAMP=${timestamp}"
DART_DEFINE_LIFESPAN="APP_BUILD_LIFESPAN_DAYS=${LIFESPAN_DAYS}"

echo "[build_with_expiry] Using timestamp: ${timestamp} (UTC)"
echo "[build_with_expiry] Lifespan: ${LIFESPAN_DAYS} days"
echo "[build_with_expiry] Running flutter analyze..."
flutter analyze

echo "[build_with_expiry] Building APK (${BUILD_MODE})..."
case "${BUILD_MODE}" in
  debug)
    flutter build apk --debug --dart-define="${DART_DEFINE}" --dart-define="${DART_DEFINE_LIFESPAN}"
    ;;
  profile)
    flutter build apk --profile --dart-define="${DART_DEFINE}" --dart-define="${DART_DEFINE_LIFESPAN}"
    ;;
  release)
    flutter build apk --release --dart-define="${DART_DEFINE}" --dart-define="${DART_DEFINE_LIFESPAN}"
    ;;
esac

echo "[build_with_expiry] Done. APK with ${LIFESPAN_DAYS}-day lifespan generated."
