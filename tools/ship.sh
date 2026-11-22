#!/usr/bin/env bash
# Build the Flutter app and deliver it to your phone.
#
#   tools/ship.sh wifi  ["release notes"]   install over Wi-Fi (adb); phone on the same network
#   tools/ship.sh cloud ["release notes"]   upload to Firebase App Distribution; works from anywhere
#   tools/ship.sh both  ["release notes"]   do both
#
# Config lives in tools/.env (git-ignored). Copy tools/env.example to start.
set -euo pipefail
cd "$(dirname "$0")/.."

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

mode="${1:-}"
case "$mode" in
  wifi|cloud|both) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 1 ;;
esac
notes="${2:-$(git log -1 --pretty=%s 2>/dev/null || echo 'dev build')}"

if [ -f tools/.env ]; then set -a; . tools/.env; set +a; fi

BUILD_MODE="${BUILD_MODE:-release}"        # release | profile | debug
build_number="$(( $(date +%s) / 60 ))"     # always increasing, so each build installs as an update

echo "==> Building $BUILD_MODE APK (build $build_number)"
flutter build apk "--$BUILD_MODE" \
  --build-number="$build_number"
# NOTE: never pass tokens via --dart-define: they end up readable inside the APK.

apk="build/app/outputs/flutter-apk/app-$BUILD_MODE.apk"
[ -f "$apk" ] || { echo "APK not found at $apk" >&2; exit 1; }

install_wifi() {
  local serial="${ANDROID_SERIAL:-}"
  if [ -z "$serial" ]; then
    serial="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi
  if [ -z "$serial" ]; then
    echo "No adb device found. Run tools/wifi-connect.sh, or use 'cloud'." >&2
    return 1
  fi
  echo "==> Installing on $serial"
  adb -s "$serial" install -r "$apk"

  local pkg
  pkg="$(grep -Eho 'applicationId[[:space:]]*=?[[:space:]]*"[^"]+"' android/app/build.gradle* 2>/dev/null \
        | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  if [ -n "$pkg" ]; then
    adb -s "$serial" shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null
  fi
}

upload_cloud() {
  : "${FIREBASE_APP_ID:?Set FIREBASE_APP_ID in tools/.env}"
  echo "==> Uploading to Firebase App Distribution (groups: ${FIREBASE_GROUPS:-me})"
  firebase appdistribution:distribute "$apk" \
    --app "$FIREBASE_APP_ID" \
    --groups "${FIREBASE_GROUPS:-me}" \
    --release-notes "$notes"
}

case "$mode" in
  wifi)  install_wifi ;;
  cloud) upload_cloud ;;
  both)  install_wifi || echo "(wifi install skipped)"; upload_cloud ;;
esac

echo "==> Done: build $build_number - $notes"
