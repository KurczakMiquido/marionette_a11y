#!/usr/bin/env bash
# Usage: run.sh <serial> <targetPackage> <out.json>
# Reads the accessibility tree of the app on screen and writes it as a11y-native/v1 JSON.
set -euo pipefail

fail() {
  echo "android probe: $*" >&2
  exit 1
}

[ $# -eq 3 ] || fail "usage: run.sh <serial> <targetPackage> <out.json>"
serial=$1
package=$2
out=$3

here=$(cd "$(dirname "$0")" && pwd)
app_apk=$here/build/outputs/apk/debug/a11y-probe-debug.apk
test_apk=$here/build/outputs/apk/androidTest/debug/a11y-probe-debug-androidTest.apk
stamp=$here/build/probe.stamp
build_log=$here/build/probe-build.log

command -v adb >/dev/null || fail "adb not found on PATH"
command -v python3 >/dev/null || fail "python3 not found on PATH"
[ "$(adb -s "$serial" get-state 2>/dev/null)" = device ] || fail "device $serial is not connected"

# Gradle leaves an up-to-date APK untouched, so a stamp marks the last successful build.
if [ ! -f "$app_apk" ] || [ ! -f "$test_apk" ] || [ ! -f "$stamp" ] ||
  [ -n "$(find "$here/src" "$here"/*.gradle.kts "$here/gradle.properties" -newer "$stamp" | head -1)" ]; then
  [ -f "$here/local.properties" ] || [ -n "${ANDROID_HOME:-}${ANDROID_SDK_ROOT:-}" ] ||
    fail "Android SDK not found: set ANDROID_HOME or sdk.dir in $here/local.properties"
  mkdir -p "$here/build"
  "$here/gradlew" -p "$here" assembleDebug assembleDebugAndroidTest >"$build_log" 2>&1 ||
    fail "gradle build failed, see $build_log"
  touch "$stamp"
fi

for apk in "$app_apk" "$test_apk"; do
  result=$(adb -s "$serial" install -r -t "$apk" 2>&1 | tr -d '\r' | grep . | tail -1) || true
  [ "$result" = Success ] || fail "installing $(basename "$apk") failed: $result"
done

output=$(adb -s "$serial" shell am instrument -w -e targetPackage "$package" -e device "$serial" \
  dev.a11y.probe.test/androidx.test.runner.AndroidJUnitRunner </dev/null 2>&1 | tr -d '\r') ||
  fail "am instrument failed: $(grep . <<<"$output" | tail -1)"

if ! grep -q '^OK (1 test)' <<<"$output"; then
  reason=$(grep -m1 -E '^[A-Za-z0-9_.$]+(Exception|Error)(: |$)' <<<"$output" ||
    grep -m1 -E '^INSTRUMENTATION_(FAILED|RESULT: shortMsg)' <<<"$output" ||
    grep . <<<"$output" | tail -1)
  fail "probe failed: $reason"
fi

remote=$(sed -n 's/.*A11Y_NATIVE_JSON_PATH=//p' <<<"$output" | head -1)
[ -n "$remote" ] || fail "probe did not report where it wrote the JSON"
adb -s "$serial" pull "$remote" "$out" >/dev/null 2>&1 || fail "could not pull $remote to $out"
python3 -m json.tool "$out" >/dev/null 2>&1 || {
  rm -f "$out"
  fail "probe output is not valid JSON"
}
