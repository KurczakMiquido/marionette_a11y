# Plan: milestone 2 — report, tooltip, role check, widget tests, agent skill

Spec: `docs/specs/report-and-testing.md` (binding), on top of `docs/specs/native-probes.md`. Read the section your
task names before starting.

## Global Constraints

- Repo: `/Users/michalkurczak/Development/marionette_a11y`, branch `feature/report-and-testing`. Commit to this branch
  only. Never push.
- Commit messages: English, one line, no `Co-Authored-By` or any AI attribution.
- Flutter/Dart via fvm: `fvm flutter ...`, `fvm dart ...` (Flutter 3.44.8, Dart 3.12). Engine sources for checking
  platform behaviour: `~/fvm/versions/3.44.8/engine/src/flutter/shell/platform/`.
- Dart: exact dependency versions (no `^`), one public class per file named after the file, short English comments
  only where they explain a why, `fvm dart format --line-length 120`, analyze clean (`fvm flutter analyze` in the
  package and `example/`, `fvm dart analyze` in `cli/`).
- Full test run: `fvm flutter test && (cd example && fvm flutter test) && (cd cli && fvm dart test)`. All green before
  each commit.
- Build outputs and IDE files are git-ignored, never committed.
- Committed code never taps or navigates the app. For device verification you may navigate with `adb -s emulator-5580
  shell input tap <x> <y>` or the iOS simulator control tool.
- Test devices (running):
  - Android: emulator `emulator-5580` (AVD Diag_QA_2, Android 15, density 420), example app
    `dev.poc.marionette_a11y_example`.
  - iOS: simulator UDID `3A884E30-6905-4C55-AF19-133A7AB73B8D` (iPhone 17, iOS 26.4), example app
    `dev.poc.marionetteA11yExample`.
  - Never use or touch `emulator-5554` or `emulator-5570` (other agents).
  - After changing `lib/` or `example/lib/`, rebuild and reinstall the example app on the device you verify with
    (`fvm flutter build apk --debug` + `adb install -r`; `fvm flutter build ios --simulator --debug` +
    `xcrun simctl install` + `xcrun simctl launch`). The VM service URI: README section "Native check".
- Disk is limited: delete only build outputs you created; never touch caches.

## Task 1: Tooltip in the Flutter snapshot (spec §1)

- `lib/src/a11y_node.dart`: `toJson` adds `tooltip` when non-empty. Test in `test/a11y_snapshot_test.dart`.
- `cli/`: `FlutterNode.tooltip` (fromJson/toJson, absent when empty) and a derived `label` getter per spec.
  `CrossCheck` composes per spec §1 for iOS and Android; messages list `tooltip` when it took part.
- Tests in `cli/test/cross_check_test.dart`: iOS label+tooltip joined with `\n` matches; iOS tooltip-only matches;
  Android label+tooltip compares without the tooltip; Android tooltip-only with empty value/label/hint matches;
  Android value + tooltip (no label) composes the value only; a real mismatch names `tooltip` in its message.
- Example app `example/lib/controls_screen.dart`: add one control whose semantics node has both a non-empty label and
  a tooltip. Prove it with a widget test in `example/test/controls_screen_test.dart` reading `A11ySnapshot.capture()`
  (if a plain `Tooltip` around a button does not produce one node with both, use an explicit
  `Semantics(container: true, button: true, label: …, tooltip: …, onTap: …)`).
- Verify: rebuild both devices, open Kontrolki, run `a11y check` on both. Expected: no `name-mismatch` for the new
  control on either platform, and the native iOS label of it contains both texts. Paste both summaries and the
  native node JSON of the control into the report.

## Task 2: `role-mismatch` and WCAG on findings (spec §2, §3)

- `cli/lib/src/models/finding.dart`: optional `wcag`. `CrossCheck`: the `role-mismatch` rule, `wcag` on cross-check
  findings and on passed-through native issues per the spec table (one lookup, in its own small class or a const
  map in the cross-check file).
- Tests: rule fires (iOS-like tap node matched to `other`/`staticText` non-clickable), does not fire for a clickable
  native node, for a non-interactive Flutter text, or for an unmatched node; `wcag` present for a mapped ATF check,
  an Apple check and a cross-check rule, absent for an unknown check; JSON round-trip leaves `wcag` out when null.
- Verify: on the iOS simulator open "Wersja z błędami" and run `check`. Expected: `role-mismatch` on the back-arrow
  tap target. On Android the same screen: report whether it fires (expected: not, the bridge marks it clickable).
  Paste both summaries.

## Task 3: `check` collects the Flutter audit and transcript (spec §4)

- `FlutterSnapshotClient`: `snapshot({String locale})` returns nodes and transcript; new `audit()` calling
  `ext.flutter.a11y.audit` and mapping to `Finding`s with `source: "flutter"`. 30 s timeouts on every call after
  connecting. `webSocketUri` fix.
- `CheckCommand`: `--locale` option; findings ordered flutter → crosscheck → native; `CheckReport` writes
  `flutter.transcript`. Keep `CrossCheck.run` pure; join the lists in the command or report.
- Tests: client mapping of a recorded audit response (fixture from the real extension, stored under
  `cli/test/fixtures/`), screen-level finding without rect, timeout path (a fake service or a VM service of a test
  isolate that never answers is acceptable; a unit-level seam is fine), `/ws` URI cases, report JSON has
  `flutter.transcript`, runner test that `--locale` reaches the snapshot call.
- Verify: `check` on Android booking "Wersja z błędami". Expected: flutter findings (`missing-name`, `target-size`,
  `generic-name`, `role-in-name`, …) at the top of the summary, then cross-check and ATF. Paste the summary.

## Task 4: HTML report (spec §5)

- `--html <file>` on `check`. Screenshot in its own class (`Screenshotter` or similar) with a process seam for tests;
  PNG size from IHDR; the renderer in its own class taking the `CheckReport`, transcript, optional PNG bytes, device
  and timestamp, returning the HTML string. No packages beyond the existing ones unless unavoidable (then exact
  version, say why in the report).
- Tests: grouping (by flutterId, by nativePath via matches, by native path alone, by rect, screen-level), numbering
  order, box percentages, escaping of `<script>` in a label and a message, no `http` reference in the output except
  inside escaped app text, screenshot failure → report still written and stderr line, IHDR parsing and the 2%
  alignment warning.
- Verify on both devices with "Wersja z błędami": write `report-android.html` and `report-ios.html` to the scratch
  directory given in your dispatch (not the repo). Open each in the built-in browser pane, take a screenshot, check
  that boxes sit on the elements they name (the calendar icon, the two 16 pt "Usuń" buttons, the back arrow). Put
  the report paths and what you checked in the report.

## Task 5: Widget-test API (spec §6)

- `lib/testing.dart` exporting `A11yAuditGuideline` and `matchesA11yTranscript` from `lib/src/testing/`.
  `pubspec.yaml`: `flutter_test` into `dependencies`.
- Tests in `test/testing_test.dart`: guideline passes a clean screen, fails an unnamed button with the reason format,
  `failOn: warning` fails a warning-only screen, empty snapshot message; transcript matcher passes equal, fails with
  diff, fails on a missing file with the message, writes the file when `autoUpdateGoldenFiles` is true (restore it in
  `tearDown`), resolves relative to `LocalFileComparator.basedir`.
- Example: `example/test/booking_screen_test.dart` adds the guideline on the fixed variant, an expected failure on
  the broken one (evaluate the guideline and assert the reason contains `missing-name`), and transcript goldens for
  both variants under `example/test/goldens/`, generated with `--update-goldens` and committed.
- README: section "Widget tests" with the three-line usage, `--update-goldens`, and `textContrastGuideline`.

## Task 6: Agent skill (spec §7)

- `skills/a11y-audit/SKILL.md` per spec §7, grounded in this repo's README and both specs; every command in it must
  be one you ran in this task.
- README: one paragraph pointing to the skill and how to use it from Claude Code (copy or symlink the directory into
  `~/.claude/skills/`; do not do it).
- Verify the skill: give a fresh general-purpose subagent only the skill file path and the task "Audit the broken
  booking screen of the example app (`dev.poc.marionette_a11y_example` on `emulator-5580`, already on that screen)
  and write an HTML report to <scratch dir>". This one subagent is allowed (it tests the skill, it does not review
  code). Record where it hesitated, guessed or improvised; fix the skill for each; note the outcome in the report.
