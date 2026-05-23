#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

# === Config ===
GITEA_HOST="${GITEA_HOST:-git.cyberius.biz}"
GITEA_TOKEN="${GITEA_TOKEN:-}"
REPO="h-1.flutter.0"
OWNER="${GITEA_OWNER:-$(git config user.name 2>/dev/null || echo "user")}"

# === Read version ===
VERSION="$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' ')"
if [ -z "${VERSION}" ]; then
  echo "Error: Could not read version from pubspec.yaml" >&2
  exit 1
fi
echo "=== Version: ${VERSION} ==="

# === Build APK ===
echo ""
echo "=== Step 1: Build release APK ==="
bash scripts/build_with_expiry.sh release

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "${APK_PATH}" ]; then
  echo "Error: APK not found at ${APK_PATH}" >&2
  exit 1
fi

APK_NAME="h-1_flutter_${VERSION}.apk"
cp "${APK_PATH}" "/tmp/${APK_NAME}"

# === Check token ===
if [ -z "${GITEA_TOKEN}" ]; then
  echo ""
  echo "=== GITEA_TOKEN not set ==="
  echo "Set it with: export GITEA_TOKEN=your_token"
  echo "Get token from: https://${GITEA_HOST}/user/settings/applications"
  exit 1
fi

API_BASE="https://${GITEA_HOST}/api/v1"
REPO_API="${API_BASE}/repos/${OWNER}/${REPO}"

echo ""
echo "=== Step 2: Create release ==="
RELEASE_RESPONSE=$(curl -s -X POST "${REPO_API}/releases" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(cat <<EOF
{
  "tag_name": "v${VERSION}",
  "name": "v${VERSION}",
  "body": "ビルド ${VERSION}",
  "draft": false,
  "prerelease": false
}
EOF
)")

RELEASE_ID=$(echo "${RELEASE_RESPONSE}" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
if [ -z "${RELEASE_ID}" ]; then
  echo "Error: Failed to create release. Response:" >&2
  echo "${RELEASE_RESPONSE}" >&2
  exit 1
fi
echo "Release created: ID=${RELEASE_ID}"

echo ""
echo "=== Step 3: Upload APK ==="
UPLOAD_URL="${API_BASE}/repos/${OWNER}/${REPO}/releases/${RELEASE_ID}/assets?name=${APK_NAME}"
curl -s -X POST "${UPLOAD_URL}" \
  -H "Authorization: token ${GITEA_TOKEN}" \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary @"/tmp/${APK_NAME}" > /dev/null

echo ""
echo "=== Done ==="
echo "Release: https://${GITEA_HOST}/${OWNER}/${REPO}/releases/tag/v${VERSION}"
echo "APK: ${APK_NAME}"
