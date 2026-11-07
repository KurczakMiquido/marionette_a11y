#!/usr/bin/env bash
# Usage: run.sh <simulatorUdid> <bundleId> <out.json>
# Reads the accessibility tree of the app on screen and writes it as a11y-native/v1 JSON.
set -euo pipefail

fail() {
  echo "ios probe: $*" >&2
  exit 1
}

[ $# -eq 3 ] || fail "usage: run.sh <simulatorUdid> <bundleId> <out.json>"
udid=$1
bundle_id=$2
out=$3

here=$(cd "$(dirname "$0")" && pwd)
build=$here/build
derived=$build/DerivedData
stamp=$build/probe.stamp
build_log=$build/probe-build.log
test_log=$build/probe-test.log
result=$build/probe.xcresult

command -v xcodebuild >/dev/null || fail "xcodebuild not found; install Xcode"
command -v python3 >/dev/null || fail "python3 not found on PATH"
xcrun simctl list devices booted | grep -q "($udid) (Booted)" || fail "simulator $udid is not booted"
xcrun simctl get_app_container "$udid" "$bundle_id" >/dev/null 2>&1 ||
  fail "$bundle_id is not installed on simulator $udid"

xctestrun() { ls -t "$derived"/Build/Products/*.xctestrun 2>/dev/null | head -1; }

# xcodebuild always relinks and re-signs, so a stamp marks the last successful build.
if [ -z "$(xctestrun)" ] || [ ! -f "$stamp" ] ||
  [ -n "$(find "$here/A11yProbeUITests" "$here/A11yProbe.xcodeproj" -newer "$stamp" -not -path '*/xcuserdata/*' |
    head -1)" ]; then
  mkdir -p "$build"
  rm -f "$stamp"
  xcodebuild build-for-testing -project "$here/A11yProbe.xcodeproj" -scheme A11yProbe \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$derived" >"$build_log" 2>&1 ||
    fail "xcodebuild build-for-testing failed, see $build_log"
  touch "$stamp"
fi

rm -rf "$result"
if ! TEST_RUNNER_TARGET_BUNDLE_ID=$bundle_id xcodebuild test-without-building -xctestrun "$(xctestrun)" \
  -destination "id=$udid" -derivedDataPath "$derived" -resultBundlePath "$result" >"$test_log" 2>&1; then
  reason=$(grep -m1 -E 'error: -\[A11yProbeUITests' "$test_log" | sed -E 's/.*testDump\] : (failed - )?//' ||
    grep -m1 -E 'error:' "$test_log" || tail -1 "$test_log")
  fail "probe failed: $reason (log: $test_log)"
fi

payload=$(sed -n 's/.*A11Y_NATIVE_JSON_BEGIN\([A-Za-z0-9+/=]*\)A11Y_NATIVE_JSON_END.*/\1/p' "$test_log" | head -1)
[ -n "$payload" ] || fail "probe printed no JSON, see $test_log"
base64 -D <<<"$payload" >"$out" 2>/dev/null || fail "could not decode the probe output"
python3 -m json.tool "$out" >/dev/null 2>&1 || {
  rm -f "$out"
  fail "probe output is not valid JSON"
}
