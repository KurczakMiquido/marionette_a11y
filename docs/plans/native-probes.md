# Plan: native accessibility probes (milestone 1)

Spec: `docs/specs/native-probes.md` (binding). Read it before starting any task.

## Global Constraints

- Repo: `/Users/michalkurczak/Development/marionette_a11y`, branch `feature/native-probes`. Commit to this branch only. Never push.
- Commit messages: English, one line, no `Co-Authored-By` or any AI attribution.
- Flutter/Dart via fvm: `fvm flutter ...`, `fvm dart ...` (Flutter 3.44.8, Dart 3.12).
- Dart: exact dependency versions (no `^`), one public class per file named after the file, short English comments
  only where they explain a why, `fvm dart format --line-length 120`, `fvm dart analyze` clean.
- Kotlin/Swift: same comment rule; no third-party dependencies besides AndroidX Test, UiAutomator and Google ATF.
- Build outputs and IDE files are git-ignored, never committed.
- Probes never launch, relaunch, navigate or tap the target app. They read what is on screen now.
- Test devices for verification (already running):
  - Android: emulator `emulator-5580` (AVD Diag_QA_2, Android 15, density 420). Example app
    `dev.poc.marionette_a11y_example` is in the foreground on its "broken" booking screen.
  - iOS: simulator UDID `3A884E30-6905-4C55-AF19-133A7AB73B8D` (iPhone 17, iOS 26.4, Xcode 26.4.1). Example app
    `dev.poc.marionetteA11yExample` is running on its home screen.
  - Do not use or touch other emulators (`emulator-5554`, `emulator-5570` belong to other agents).

## Task 1: `a11y_cli` package with the native and Flutter models

Create pure Dart package `cli/` named `a11y_cli` (no Flutter dependency).

- Models per spec, each with `fromJson` and `toJson`: `NativeTree` (whole `a11y-native/v1` document), `NativeNode`,
  `NativeIssue`, `FlutterNode`. Rect as a small value class `A11yRect` (left, top, width, height) with `iou(other)`
  and `fromList`/`toList`.
- `NativeTree.fromJson` rejects a document whose `schema` is not `a11y-native/v1` with a `FormatException`.
- Fixtures in `cli/test/fixtures/`: `native_android.json` and `native_ios.json` (hand-written, 4–6 nodes each,
  covering a button, a text field with hint, an unnamed clickable, one issue) and `flutter_snapshot.json`.
- Tests: round-trip each fixture through `fromJson`/`toJson`; IoU of identical, disjoint and half-overlapping rects;
  wrong schema throws.
- `bin/a11y.dart` prints usage and exits 1 for now.
- Done when `fvm dart test` in `cli/` passes and analyze is clean.

## Task 2: Android probe

Create `probes/android/`: a Gradle project whose instrumentation test reads the foreground target app's
accessibility tree and runs ATF.

- Project: one module; the probe lives in `androidTest`. Package `dev.a11y.probe`. Copy the Gradle wrapper and match
  AGP/Kotlin versions from `example/android/` (it builds today). Add
  `com.google.android.apps.common.testing.accessibility.framework:accessibility-test-framework` (latest stable,
  exact version) and AndroidX Test runner/UiAutomator.
- Test `A11yProbeTest.dump()`: argument `targetPackage` from instrumentation arguments. Use `UiAutomation` with
  `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`; enable `FLAG_RETRIEVE_INTERACTIVE_WINDOWS`; take the root of the
  window whose package is `targetPackage` (fail clearly if absent).
- Walk the tree to NativeNodes exactly per spec (including `hintText`, `isHeading`, `stateDescription`).
- ATF: build an `AccessibilityHierarchyAndroid` from the same root, run the `LATEST` preset hierarchy checks with a
  `UiAutomation.takeScreenshot()` image in the parameters, map results to NativeIssues per spec. Resolve `nodePath`
  by matching the result element's bounds to a walked node.
- Write the JSON to a file readable by adb (e.g. `/data/local/tmp/a11y-native.json` or the probe's external files
  dir) and print its path.
- `run.sh <serial> <targetPackage> <out.json>`: build with Gradle if the APKs are missing or sources are newer,
  install both APKs, run `am instrument -w`, pull the JSON to `out.json`, verify it parses (`python3 -m json.tool`),
  exit non-zero with a one-line reason on any failure.
- Verify on `emulator-5580` against `dev.poc.marionette_a11y_example` (broken screen). Expected in the output: an
  `EditText` node with `hint` "E-mail"; a clickable button with empty label (calendar icon); two 16×16 "Usuń"
  buttons; ATF issues including a touch target size check and a speakable text check. Paste the relevant JSON
  excerpt into the report.

## Task 3: iOS probe

Create `probes/ios/`: an Xcode project with a UI testing bundle that reads the running target app's tree and runs
Apple's audit.

- `probes/ios/A11yProbe.xcodeproj`, UI testing bundle target `A11yProbeUITests`, shared scheme `A11yProbe`. Prefer
  no host app (UI tests use `XCUIApplication(bundleIdentifier:)`); if xcodebuild refuses a UI test bundle without a
  target application, add the smallest possible SwiftUI host app and say so in the report.
- Test `testDump`: target bundle id from env `TARGET_BUNDLE_ID` (passed as `TEST_RUNNER_TARGET_BUNDLE_ID`).
  `activate()` the app, never `launch()`. Walk `try app.snapshot()` to NativeNodes per spec. Run
  `app.performAccessibilityAudit(for: .all)` collecting every issue (return `true` from the handler so the test does
  not fail), map to NativeIssues per spec, resolve `nodePath` by element frame.
- Output: print `A11Y_NATIVE_JSON_BEGIN<base64 of the JSON>A11Y_NATIVE_JSON_END` on one line.
- `run.sh <udid> <bundleId> <out.json>`: `build-for-testing` once into `probes/ios/build/` (rebuild when sources are
  newer), then `test-without-building` with `-destination id=<udid>`, extract the marker from the log, base64-decode
  to `out.json`, verify it parses, exit non-zero with a one-line reason on failure.
- Verify on the booted simulator `3A884E30-6905-4C55-AF19-133A7AB73B8D` against `dev.poc.marionetteA11yExample`.
  To check the broken screen, you may tap "Wersja z błędami" with a throwaway method or tool, but nothing that taps
  or navigates may stay in the committed probe. Expected: buttons "Wersja z błędami" and "Wersja poprawiona" on the
  home screen; on the broken screen an unnamed button and two small "Usuń" buttons, and Apple audit issues. Paste the
  relevant JSON excerpt into the report.

## Task 4: CLI `native` and `check` commands with the cross-check

Extend `cli/` (built in Task 1) with the commands from the spec's CLI section.

- `native`: resolve `run.sh` for the platform (default `../probes/<platform>/run.sh` relative to the `cli` package
  root, `--probes-dir` overrides), run it, parse the output with `NativeTree.fromJson`, write `--out`.
- `check`: run `native`, fetch the Flutter snapshot via the `vm_service` package (exact version): connect to
  `--vm-service`, find the isolate exposing `ext.flutter.a11y.snapshot`, call it with `includeRects: 'true'`,
  parse nodes into `FlutterNode`s.
- Cross-check exactly per spec (matching, the three rules, issue pass-through, normalization) in its own class with
  unit tests built on the Task 1 fixtures plus small inline cases: identifier match wins over rect, IoU threshold,
  one native node matched once, each rule fires and does not fire.
- Write `a11y-check/v1` to `--out`, print the summary per spec.
- Verify end to end on both devices from the Global Constraints. The VM service URI: Android — `adb -s <serial>
  logcat -d | grep "listening on"` then `adb forward`; iOS simulator — the URI from `xcrun simctl spawn <udid> log
  show --last 30m --predicate 'eventMessage CONTAINS "listening on"'` (loopback, no forward needed). Paste both
  summaries into the report.
