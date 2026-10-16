#!/usr/bin/env bash
# Installs the debug APK on the running emulator, launches it and checks that
# it starts up and keeps running without crashing:
#   - the game prints STAMP_ORDER_READY once the main menu is up,
#   - the process is still alive and in the foreground after a settle time,
#   - logcat shows no Java crash, native crash, ANR or GDScript error.
# Leaves logcat and a screenshot in the output directory.
#   ci/emulator_smoke_test.sh <apk> [out_dir]
set -uo pipefail

APK="$1"
OUT="${2:-build/emulator}"
PKG="com.dionysisath.stamporder"
READY_MARKER="STAMP_ORDER_READY"
READY_TIMEOUT="${READY_TIMEOUT:-180}"
SETTLE_SECONDS="${SETTLE_SECONDS:-20}"
mkdir -p "$OUT"

collect() {
  adb logcat -d > "$OUT/logcat.txt" 2>/dev/null || true
  adb exec-out screencap -p > "$OUT/$1" 2>/dev/null || true
}

fail() {
  echo "::error::$*"
  collect screenshot-failure.png
  echo "----- last logcat lines -----"
  tail -n 80 "$OUT/logcat.txt" || true
  exit 1
}

crash_check() {
  adb logcat -d > "$OUT/logcat.txt"
  local hits
  hits="$(grep -nE "FATAL EXCEPTION|Fatal signal [0-9]+|ANR in $PKG|SCRIPT ERROR|Process: $PKG|Force finishing activity $PKG|$PKG.*has died" "$OUT/logcat.txt" || true)"
  if [ -n "$hits" ]; then
    echo "$hits"
    fail "Crash or script error found in logcat ($1)"
  fi
}

adb wait-for-device
echo "Android $(adb shell getprop ro.build.version.release | tr -d '\r'), API $(adb shell getprop ro.build.version.sdk | tr -d '\r'), ABI $(adb shell getprop ro.product.cpu.abi | tr -d '\r')"

adb install -r -g "$APK" || fail "Installing $APK failed"
adb logcat -c

activity="$(adb shell cmd package resolve-activity --brief "$PKG" | tail -n 1 | tr -d '\r')"
echo "Launching $activity"
adb shell am start -W -n "$activity" || fail "Could not launch $activity"

echo "Waiting up to ${READY_TIMEOUT}s for $READY_MARKER"
ready=0
for ((t = 0; t < READY_TIMEOUT; t += 3)); do
  if adb logcat -d | grep -q "$READY_MARKER"; then
    ready=1
    echo "Main menu ready after ~${t}s"
    break
  fi
  if [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
    fail "App process died during startup"
  fi
  sleep 3
done
[ "$ready" -eq 1 ] || fail "Main menu never reported ready"
crash_check "startup"

echo "Letting the app run for ${SETTLE_SECONDS}s"
sleep "$SETTLE_SECONDS"
pid="$(adb shell pidof "$PKG" | tr -d '\r')"
[ -n "$pid" ] || fail "App is no longer running ${SETTLE_SECONDS}s after startup"
focus="$(adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp" | tr -d '\r')"
echo "$focus"
echo "$focus" | grep -q "$PKG" || fail "App is not in the foreground"
crash_check "after ${SETTLE_SECONDS}s"

collect screenshot.png
echo "Godot log:"
grep -E " godot " "$OUT/logcat.txt" | tail -n 40 || true
echo "App started and ran without crashing (pid $pid)."
