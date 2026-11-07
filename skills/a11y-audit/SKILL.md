---
name: a11y-audit
description: Use when checking a Flutter app's accessibility on Android or iOS — screen reader support (TalkBack, VoiceOver), WCAG 2.2 issues, an a11y audit of a screen or a user flow, or an HTML accessibility report; also "sprawdź dostępność", "czy TalkBack to przeczyta", "audyt a11y".
---

# Accessibility audit of a Flutter screen

`marionette_a11y` gives a running debug app two marionette MCP tools, `a11y_audit` and `a11y_snapshot`. Its `a11y` CLI
reads what TalkBack and VoiceOver actually receive, runs Google ATF or Apple's audit, and writes an HTML report.
Work one screen at a time, on an emulator or simulator. Physical devices are not supported.

## Prerequisites

- The app runs a debug build (usually the user's `flutter run`) on an Android emulator (11+) or iOS simulator (17+).
- The project has the marionette MCP server (command `marionette_mcp`); Claude Code shows its tools as
  `mcp__<server>__<tool>`, usually `mcp__marionette__connect` and so on. No such tools: ask the user to add the
  server and restart Claude Code. Never edit MCP config yourself.
- A `marionette_a11y` checkout, `<repo>` below. In a wired app `grep -A1 'marionette_a11y:' pubspec.yaml` shows its
  `path:`. Once: `cd <repo>/cli && fvm dart pub get` (rerunning is harmless).
- Android: `ANDROID_HOME`, JDK 17. iOS: Xcode. Both: `python3`. In the app use `fvm flutter` when it has `.fvmrc`,
  plain `flutter` otherwise. Run the CLI with `fvm dart` as shown; without `.fvmrc` fvm uses its global SDK.
- Device and app ids: `adb devices`, `xcrun simctl list devices booted`,
  `adb -s <serial> shell dumpsys activity activities | grep -m1 topResumedActivity` (package of the foreground app),
  `xcrun simctl listapps <udid> | grep CFBundleIdentifier`.

## Wire the app (debug only, never committed)

Try Connect first: after `connect`, `call_custom_extension` with `{"extension": "a11y.audit"}`. Wire the app only
when that answers that the extension is unknown, or when `connect` fails on a debug app whose URI is right (no
`MarionetteBinding` yet). In the app's `pubspec.yaml`:

```yaml
dependencies:
  marionette_flutter: 0.6.0
  marionette_a11y:
    path: <repo>
```

In `main()`, before `runApp` (imports: `package:flutter/foundation.dart`,
`package:marionette_flutter/marionette_flutter.dart`, `package:marionette_a11y/marionette_a11y.dart`):

```dart
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();
  registerA11yExtensions();
}
```

If the app already calls `MarionetteBinding.ensureInitialized()`, add only `registerA11yExtensions()` after it. Without
it Flutter builds no semantics tree and every audit passes. Then `fvm flutter pub get` and ask the user to restart the
app (a hot reload does not rerun `main`). Never stage or commit this wiring: `pubspec.yaml`, `pubspec.lock` and the
`main` change stay local. Commit fixes only when the user asks, staging files by path.

## Connect

The VM service URI looks like `http://127.0.0.1:<port>/<token>=/`. Take it from the user's `flutter run` output, or:

```bash
adb -s <serial> logcat -d | grep 'Dart VM service is listening' | tail -1
adb -s <serial> shell pidof <package>
adb -s <serial> forward tcp:<port> tcp:<port>
xcrun simctl spawn <udid> log show --last 3h --style compact \
  --predicate 'eventMessage CONTAINS "Dart VM service is listening"' | grep 'flutter: ' | tail -1
xcrun simctl spawn <udid> launchctl list | grep <bundle id>
```

The PID in the log line (logcat's PID column after the time, iOS `Runner[<pid>:…]`) must equal the app's current PID from `pidof`
or `launchctl`; otherwise the line is from an earlier run. Widen `--last` when the app started earlier. Nothing
found: ask the user for the URI. Each platform's app has its own URI: `connect` to the one you audit and pass the
same app's URI to that platform's check.

- marionette `connect` needs the ws form, `{"uri": "ws://127.0.0.1:<port>/<token>=/ws"}`. The http form fails with
  `Unsupported URL scheme 'http'`. The `a11y` CLI takes the http form.
- After `connect`, `a11y_snapshot` and `a11y_audit` join the tool list. When your client does not show them, call
  `call_custom_extension` with `{"extension": "a11y.audit"}` or
  `{"extension": "a11y.snapshot", "args": {"locale": "pl", "includeRects": true}}`. An unknown extension: wire the
  app (above).

## Per screen

Audit only (the user asked for a report, not fixes): steps 1–4 and 7, no fixes, no widget tests; report the fix you
propose per finding (rule, widget, file and line).

1. Navigate with marionette: `get_interactive_elements`, then `tap` by `text`, `key` or `coordinates`; `scroll_to`,
   `enter_text`, `swipe`, `press_back_button`. During a route transition `get_interactive_elements` can return 0
   elements: call `a11y_snapshot` again until the transcript shows the new screen. Probes never navigate.
2. `a11y_audit` returns `errors` and `warnings` (counts) and `findings`, each with `rule`, `wcag`, `severity`, `message` and the
   `node` (`id`, `role`, `name`, `rect`).
3. `a11y_snapshot` with `{"locale": "pl", "includeRects": true}` (`en` for an English app), plus `take_screenshots`.
   `transcript` is what TalkBack reads, in swipe order. Anything visible in the screenshot but missing from the
   transcript does not exist for a blind user. Judge yourself whether every name makes sense and the order is logical.
4. Run the check per platform where the app runs now (a booted emulator or simulator showing the screen, or the
   devices the user named). Report a platform you could not check as not checked. `<dir>`: an absolute path outside
   the app repo.

   ```bash
   cd <repo>/cli
   fvm dart run a11y_cli:a11y check --platform android --device <serial> --app <package> \
     --vm-service <http URI> --out <dir>/<screen>-android.json --html <dir>/<screen>-android.html --locale pl
   fvm dart run a11y_cli:a11y check --platform ios --device <udid> --app <bundle id> \
     --vm-service <http URI> --out <dir>/<screen>-ios.json --html <dir>/<screen>-ios.html --locale pl
   ```

   The first run per platform builds the probe and takes minutes (use a 10-minute timeout); later runs take seconds.
   Exit 0 whatever it found; exit 1 is a usage, probe or VM service failure with a one-line reason. Stdout: counts per
   severity, then one line per finding: in-app rules, cross-check, then ATF or Apple. Do not touch the device while it
   runs; on iOS XCUITest briefly brings its runner to the front. The HTML has the screenshot with a numbered box per
   finding group, the findings and the transcript. Stdout does not name the element; the JSON's `findings` do:
   `flutterId` (an `id` in `flutter.nodes` and in `a11y_snapshot`), `nativePath` (in `native.nodes`), `rect`.
5. Fix every error, then the warnings, in the app's code (table below). Findings in one group usually share one cause:
   `target-size`, `TouchTargetSizeCheck` and `hitRegion` on one icon are one fix. Find the widget by grepping the
   node's name or visible text; for an unnamed node use its neighbours in the transcript and the widget type and
   bounds (equal to `rect`) from `get_interactive_elements`.
6. Reload: `hot_reload` works only when the app runs under `flutter run`; otherwise it answers
   `Hot reload failed. The app may need a full restart.` Then ask the user to reload or restart, and navigate back.
   Repeat steps 2–4 until there are no errors on any platform.
7. Repeat steps 2–4 at text scale 2.0 (WCAG 1.4.4), writing `<screen>-<platform>-x2.json` and `.html`. Flutter
   applies it live. Note the current values, set, check the screenshot for clipped, cut or overlapping text, then
   restore the noted values:

   ```bash
   adb -s <serial> shell settings get system font_scale
   adb -s <serial> shell settings put system font_scale 2.0
   adb -s <serial> shell settings put system font_scale <noted value>
   xcrun simctl ui <udid> content_size
   xcrun simctl ui <udid> content_size accessibility-large
   xcrun simctl ui <udid> content_size <noted value>
   ```

   On iOS, `accessibility-large` is Flutter's text scale 1.94 (33/17), the closest to 2.0. Android 14+ scales
   nonlinearly: large text grows less than 2×. Both are what users get.

## Guard the fixes with widget tests

```dart
import 'package:marionette_a11y/testing.dart';

testWidgets('booking screen stays accessible', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MaterialApp(home: BookingScreen()));
  await expectLater(tester, meetsGuideline(const A11yAuditGuideline()));
  await expectLater(tester, matchesA11yTranscript('goldens/booking.txt'));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```

- `fvm flutter test --update-goldens <test file>` writes the transcript golden (one announcement per line, next to the
  test). Read it: it is what the screen reader says. Then `fvm flutter test <test file>`.
- `A11yAuditGuideline(failOn: A11ySeverity.warning)` also fails on warnings; `testing.dart` exports `A11ySeverity`.
  A failure lists every finding, one per line:
  `[error] missing-name (WCAG 4.1.2) — … — "<name>" at [l, t, w, h]`.
- The tests need `marionette_a11y` as a dev dependency. Committing them commits that dependency: ask the user first.

## Report to the user

- Per platform: the HTML and JSON paths, the CLI's counts per severity (they include the in-app rules) before and
  after the fixes, at 1.0 and 2.0 text scale.
- Each fix: rule, widget, file and line. Each remaining finding: why it stays (false positive, needs a design decision,
  needs a real screen reader).
- The final transcript and your judgement of names and order. Tests added, goldens written.
- The uncommitted wiring (`pubspec.yaml`, `pubspec.lock`, `main`) the user should revert when done.

## Rule → typical Flutter fix

| Rule (source) | Means | Typical fix |
|---|---|---|
| `missing-name` (flutter), `native-unnamed` (crosscheck), `SpeakableTextPresentCheck` (ATF), `sufficientElementDescription` (Apple) | Control has no name; the reader says only "button" | `IconButton(tooltip: 'Wybierz termin', …)`; custom tap target: `Semantics(button: true, label: '…')` |
| `missing-role` (flutter), `role-mismatch` (crosscheck), `trait` (Apple), `ClassNameCheck` (ATF) | Reacts to taps but is read as text, image or other. On a text whose rect spans a row: an unnamed tap target (icon) in that row merged into it, missing from the transcript | Real button widget (`IconButton`, `TextButton`, `ListTile(onTap:)`) instead of a bare `InkWell`/`GestureDetector`, or `Semantics(button: true)`; a merged tap target gets its own named widget |
| `target-size` (< 24), `target-size-platform` (< 48) (flutter), `TouchTargetSizeCheck` (ATF), `hitRegion` (Apple) | Touch target too small (2.5.8) | Drop `padding: EdgeInsets.zero`, `constraints: BoxConstraints()`, `MaterialTapTargetSize.shrinkWrap`; or `ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48))`. 48 dp Android, 44 pt iOS |
| `generic-name` (flutter), `LinkPurposeUnclearCheck` (ATF) | Name says nothing: "Kliknij tutaj", "button", `ic_close` | Name the purpose: `'Przeczytaj regulamin'`; decorative image: `excludeFromSemantics: true` |
| `duplicate-name` (flutter), `DuplicateSpeakableTextCheck` (ATF) | Several controls with one name | Add the object: `tooltip: 'Usuń: $itemName'` |
| `role-in-name` (flutter), `RedundantDescriptionCheck` (ATF) | Name repeats the role: "Przycisk zapisz, Przycisk" | Remove "przycisk"/"button" from `semanticsLabel` or `Semantics(label:)` |
| `usage-hint-in-name` (flutter) | Name says "dwukrotnie"/"double tap" | Remove it; the screen reader adds its own usage hint |
| `name-repeated` (flutter) | Value equals the name, read twice | Drop the duplicate `value`; keep only state in it |
| `no-heading` (flutter) | No heading to jump to (1.3.1) | `Semantics(header: true, container: true, child: Text(title))`; without `container` the flag lands on the whole row |
| `not-exposed` (crosscheck) | Flutter has the node, the platform shows nothing at its rect | Look at its box: under a route or overlay, `ExcludeSemantics`, `BlockSemantics`? Merged into a parent: `Semantics(container: true)`. Exposed with other bounds: a matching miss, report it |
| `name-mismatch` (crosscheck) | The platform reads other text than Flutter's name (Android joins value, label, hint; iOS label and tooltip) | The native text in the message is what users hear; set `label`/`semanticsLabel`, `tooltip`, `hint` so it reads right. Two different elements paired: report, do not fix |
| `TextContrastCheck` (ATF), `contrast` (Apple) | Text contrast below 4.5:1, 3:1 for large text (1.4.3) | Darker text or lighter background in the theme's `ColorScheme`; guard with `textContrastGuideline`. When the estimated foreground in the message is not the text's colour (an underline, an outline), it is a false positive: check the theme or the screenshot |
| `ImageContrastCheck` (ATF) | Icon or graphic below 3:1 (1.4.11) | Stronger icon colour |
| `TextSizeCheck` (ATF), `dynamicType`, `textClipped` (Apple) | Text does not scale or is cut at large sizes (1.4.4) | No `TextScaler.noScaling` or clamping below 2.0; no fixed heights or `maxLines: 1` around text; let it wrap and the screen scroll |
| `TraversalOrderCheck` (ATF) | Reading order conflicts with layout (1.3.2) | Order widgets in reading order; last resort `Semantics(sortKey: OrdinalSortKey(n))` |
| `DuplicateClickableBoundsCheck` (ATF) | Two clickable nodes, same bounds | Nested tap handlers: keep one, or `ExcludeSemantics` on the inner one |
| `EditableContentDescCheck` (ATF) | Text field carries a content description | Name it with `InputDecoration(labelText:)`, not a `Semantics(label:)` around the field |
| `ClickableSpanCheck` (ATF) | Link inside running text | A separate control with a clear name per link |
| `UnexposedTextCheck` (ATF), `elementDetection` (Apple) | Visible text or element missing from the tree | Text drawn by `CustomPaint` or in an image: `Semantics(label: …)`; remove a wrong `ExcludeSemantics` |

Any other ATF or Apple check: read its message, find the widget by the box in the HTML report.

## Limits: judge these yourself or say they were not checked

- The rules cover a fraction of WCAG 2.2. No errors does not mean conformant.
- Whether names make sense in context, and whether the reading order is logical.
- The transcript approximates TalkBack. VoiceOver does not run in the simulator; iOS speech is not simulated.
- A hint-only `TextField` looks named: Flutter puts `hintText` into the label.
- Focus after navigation or a dialog, announcements of state changes (snapshot again after each `tap` and compare),
  custom gestures, timing, motion, captions and colour as the only cue need a human with a real screen reader.
- Contrast comes from ATF and Apple estimates on a screenshot; an app window with `FLAG_SECURE` gives ATF a black one.
