# marionette_a11y

PoC: Flutter's semantics tree as marionette MCP tools, so an agent can check what a screen reader announces.

| MCP tool | What it returns |
|---|---|
| `a11y_snapshot` | `transcript` (what TalkBack reads, in swipe order) plus semantics `nodes` |
| `a11y_audit` | WCAG 2.2 findings: `missing-name`, `missing-role`, `target-size`, `generic-name`, `role-in-name`, `name-repeated`, `target-size-platform`, `usage-hint-in-name`, `duplicate-name`, `no-heading` |

## Check your own app

Requirements:
- The app builds with Flutter 3.44 or newer (`flutter --version`). The CLI alone needs Dart 3.8 or newer.
- Android: `ANDROID_HOME` set, JDK 17, an emulator with Android 11+.
- iOS: Xcode, a simulator with iOS 17+.
- `python3`.

1. Clone this repo and get the CLI's packages:
   ```bash
   git clone https://github.com/KurczakMiquido/marionette_a11y.git
   cd marionette_a11y/cli && dart pub get
   ```
2. In the app, wire the package in as shown in [Wire it in](#wire-it-in-debug-only-never-commit-to-the-app). Keep it
   local, do not commit it.
3. Run the app in debug on an emulator or simulator (`flutter run`), copy the `http://127.0.0.1:<port>/<token>=/` URI
   it prints, and open the screen to check.
4. From `marionette_a11y/cli`:
   ```bash
   dart run a11y_cli:a11y check --platform android --device <adb serial> --app <applicationId> \
     --vm-service <URI from flutter run> --out app.json --html app.html
   ```
   On iOS: `--platform ios --device <simulator UDID> --app <bundle id>`. Open `app.html` for the report. The first run
   builds the probe, which takes minutes. For the next screen, open it in the app and run the command again.
5. Undo the wiring in the app: `git checkout pubspec.yaml pubspec.lock lib/main.dart`.

Watch out for:
- An app that already depends on another `marionette_flutter` version: `pub get` fails until it uses 0.6.0.
- An app with its own binding class: `MarionetteBinding.ensureInitialized()` replaces the binding, so adapt that
  setup for the check.
- Flavors: `--app` is the full applicationId or bundle id of the flavor you run, e.g. with a `.dev` suffix.
- Screens with `FLAG_SECURE`, such as payments: ATF gets a black screenshot and skips its contrast checks.

With an agent instead of steps 3–5: install the MCP server (`dart pub global activate marionette_mcp`), register
`marionette_mcp` as an MCP server for the app's project in Claude Code, link the [agent skill](#agent-skill) and ask
Claude to check a screen's accessibility.

## Wire it in (debug only, never commit to the app)

```yaml
dependencies:
  marionette_flutter: 0.6.0
  marionette_a11y:
    git:
      url: https://github.com/KurczakMiquido/marionette_a11y.git
```

A local clone works too: `marionette_a11y: {path: ../marionette_a11y}`. In `main.dart`, first thing in `main()`,
before any `WidgetsFlutterBinding.ensureInitialized()` (keep that call for release builds), with imports
`package:marionette_flutter/marionette_flutter.dart` and `package:marionette_a11y/marionette_a11y.dart`:

```dart
if (kDebugMode) {
  MarionetteBinding.ensureInitialized();
  registerA11yExtensions();
}
```

`registerA11yExtensions()` also calls `SemanticsBinding.ensureSemantics()`. Without it Flutter builds no semantics tree
and every audit passes.

## Agent loop

1. `a11y_audit`: fix every `error`.
2. `a11y_snapshot` + `take_screenshots`: anything visible but missing from `transcript` is invisible to blind users.
   Judge whether names make sense and the order is logical.
3. Set text scale 2.0 and repeat (WCAG 1.4.4): `adb -s <serial> shell settings put system font_scale 2.0` on Android,
   `xcrun simctl ui <udid> content_size accessibility-large` on iOS (close to 2.0). Restore the old value afterwards;
   the skill has the commands.
4. After each `tap`, snapshot again: a state change must show up in the transcript.

## Agent skill

[skills/a11y-audit/SKILL.md](skills/a11y-audit/SKILL.md) teaches Claude Code the whole audit of a screen: wiring,
connecting marionette, `a11y_audit` and `a11y_snapshot`, `a11y check --html` per platform, a typical Flutter fix per
rule, text scale 2.0, widget tests to guard the fixes and what to report. To use it, copy or symlink the
`skills/a11y-audit` directory into `~/.claude/skills/` (every project) or `<app>/.claude/skills/` (one app), open
Claude Code in the app's project, which needs the marionette MCP server, and ask it to audit a screen's accessibility.

## Widget tests

```dart
import 'package:marionette_a11y/testing.dart';

final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(const A11yAuditGuideline()));
await expectLater(tester, matchesA11yTranscript('goldens/booking.txt'));
```

`A11yAuditGuideline(failOn: A11ySeverity.warning)` also fails on warnings. The transcript golden is a text file, one
announcement per line, resolved like `matchesGoldenFile`; `flutter test --update-goldens` writes it. Add
`marionette_a11y` as a dev dependency. For contrast use flutter_test's `textContrastGuideline`.

## Limits

- Rules cover a fraction of WCAG. A hint-only `TextField` is invisible here: Flutter puts `hintText` into the label.
- The transcript approximates TalkBack. Calibrate against a real TalkBack speech log before trusting wording.
- iOS speech is not simulated: VoiceOver does not run in the iOS simulator. The native check below shows what iOS
  exposes to VoiceOver.

## Native check: what TalkBack and VoiceOver receive

A probe per platform reads the native accessibility tree of the running app and runs the platform's own checks:
Android with UiAutomation and the Accessibility Test Framework (ATF), iOS with XCUITest and Apple's accessibility
audit. The `a11y` CLI in `cli/` runs a probe and compares its tree with the Flutter semantics snapshot. It reports
Flutter nodes the platform does not expose, names and roles that reach the screen reader differently, unlabeled native
controls, and every ATF or Apple issue.

Prerequisites:
- Android: `ANDROID_HOME` set (the probe's `local.properties` is git-ignored), JDK 17 on `JAVA_HOME` or `PATH`, an
  emulator with Android 11+.
- iOS: Xcode, a simulator with iOS 17+.
- `python3`, and `cd cli && fvm dart pub get` once.
- The app calls `registerA11yExtensions()` and already shows the screen to check. Probes never launch or navigate it.

```bash
cd cli
fvm dart run a11y_cli:a11y native --platform android --device emulator-5580 --app <package> --out native.json
fvm dart run a11y_cli:a11y check --platform ios --device <simulator UDID> --app <bundle id> \
  --vm-service <VM service URI> --out check.json
```

The VM service URI is the `http://127.0.0.1:<port>/<token>=/` line `flutter run` prints. For an app started
otherwise:
- Android: `adb -s <serial> logcat -d | grep 'Dart VM service is listening'`, then
  `adb -s <serial> forward tcp:<port> tcp:<port>`.
- iOS: `xcrun simctl spawn <udid> log show --last 10m --style compact --predicate 'eventMessage CONTAINS "Dart VM service"'`.

`native` writes the native tree (`a11y-native/v1`). `check` writes `a11y-check/v1` and prints counts per severity
plus one line per finding: the in-app audit first, then the cross-check, then the native issues. It also stores the
screen reader transcript (`--locale pl|en`, default `pl`). `--html report.html` also writes one self-contained page
with a screenshot of the screen, a numbered box per finding group and the transcript. Formats and rules:
[docs/specs/native-probes.md](docs/specs/native-probes.md), [docs/specs/report-and-testing.md](docs/specs/report-and-testing.md). Exit code 0 when the command ran, whatever it found; 1 on
a usage, probe or VM service failure. The first run builds the probe, which takes minutes; later runs take seconds.

Limits:
- Emulator and simulator only.
- XCUITest briefly brings its runner to the front, so an app that blurs or locks itself when inactive is read in
  that state.
- An app window with `FLAG_SECURE` gives ATF a black screenshot, so its contrast checks see nothing.

## Run

```bash
fvm flutter test && (cd example && fvm flutter test) && (cd cli && fvm dart test)
```
