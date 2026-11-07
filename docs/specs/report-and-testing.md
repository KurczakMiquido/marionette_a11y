# Milestone 2: report, tooltip, role check, widget tests, agent skill — spec

Goal: one command gives a shareable HTML report of everything wrong on a screen (Flutter rules, cross-check, ATF or
Apple audit) drawn as boxes on a real screenshot. Flutter developers guard accessibility in `flutter test` without a
device. An agent skill drives the whole loop. Builds on `docs/specs/native-probes.md` (milestone 1), which stays
binding where this spec does not change it.

Out of scope: physical devices, several screens in one report, a translated report UI (English only), CI pipeline
files, contrast computed by our own code.

## 1. Tooltip in the Flutter snapshot

- In-app `A11yNode.toJson` adds `tooltip` (string, present only when non-empty). `name` is unchanged: the label, else
  the tooltip.
- CLI `FlutterNode` reads and writes `tooltip` (optional, absent when empty). It derives `label`: empty when `tooltip`
  is non-empty and `name == tooltip`, otherwise `name`. A label equal to its tooltip is indistinguishable from no
  label; accepted.
- `name-mismatch` composes the native text from label and tooltip as the Flutter 3.44 engine does:
  - iOS (`SemanticsObject.mm`, `accessibilityLabel`): label and tooltip, the non-empty ones joined with `"\n"`.
    Compared with native `label`, or with native `hint` when native `label` is empty (as before).
  - Android (`AccessibilityBridge.java`, API 28+): content description is value, label, hint, the non-empty ones
    joined with `", "`; when all three are empty, the tooltip. A text field's hint text is label and hint joined with
    `", "` (no tooltip). Everything else as in milestone 1.
  - The message lists the Flutter parts that were composed, `tooltip` included, e.g.
    `Flutter name + tooltip "Zapisz\nZapisuje ustawienia" differs from native label "Zapisz"`.

## 2. Rule `role-mismatch`

| rule | source | severity | when |
|---|---|---|---|
| `role-mismatch` | `crosscheck` | warning | matched pair; the Flutter node has a `tap` action or role `button`, `link`, `textField`, `checkbox`, `radio`, `toggle` or `slider`; the native node is not `clickable` and its role is `text`, `other` or `image` |

Message: `Flutter <role> "<name>" is a control, but the platform exposes <nativeType> "<label>" with no control role`
(empty name or label written as `""`).

Flutter's Android bridge makes every node with a tap action clickable, so this rule fires mostly on iOS, where a tap
without the button flag becomes static text or `other`.

## 3. WCAG reference on findings

`Finding` gets an optional `wcag` key (success criterion number as a string, e.g. `"4.1.2"`), absent when unknown.

| source | rule or check | wcag |
|---|---|---|
| crosscheck | `not-exposed`, `name-mismatch`, `native-unnamed`, `role-mismatch` | 4.1.2 |
| flutter | every rule | the in-app finding's `wcag` |
| atf | `TouchTargetSizeCheck` | 2.5.8 |
| atf | `TextContrastCheck` | 1.4.3 |
| atf | `ImageContrastCheck` | 1.4.11 |
| atf | `TextSizeCheck` | 1.4.4 |
| atf | `TraversalOrderCheck` | 1.3.2 |
| atf | `LinkPurposeUnclearCheck` | 2.4.4 |
| atf | `DuplicateSpeakableTextCheck` | 2.4.6 |
| atf | `SpeakableTextPresentCheck`, `EditableContentDescCheck`, `RedundantDescriptionCheck`, `DuplicateClickableBoundsCheck`, `ClickableSpanCheck`, `UnexposedTextCheck`, `ClassNameCheck` | 4.1.2 |
| apple | `contrast` | 1.4.3 |
| apple | `hitRegion` | 2.5.8 |
| apple | `dynamicType`, `textClipped` | 1.4.4 |
| apple | `elementDetection`, `sufficientElementDescription`, `trait` | 4.1.2 |

Any other check: no `wcag`.

## 4. `check` collects the Flutter audit and transcript

- `check` calls `ext.flutter.a11y.snapshot` (`includeRects: 'true'`, `locale`) and `ext.flutter.a11y.audit` (no
  arguments) on the same isolate.
- New option `--locale pl|en`, default `pl`: language of the transcript.
- Each in-app audit finding becomes a `Finding` with `source: "flutter"`, its `rule`, `severity`, `message`, `wcag`,
  `flutterId` = the finding node's `id` and `rect` = its `rect`; both absent for a screen-level finding. Findings are
  ordered: flutter, then crosscheck, then native issues.
- `a11y-check/v1` gains `flutter.transcript` (list of strings). The schema name stays `a11y-check/v1`: every
  addition is an optional key or a new `source` value.
- Every VM service call after connecting (`getVM`, `getIsolate`, `callServiceExtension`) times out after 30 s with
  `VM service did not answer <call> within 30 s; is the app paused in a debugger?`.
- `webSocketUri` does not append a second `ws` to an `http` URI whose path already ends in `ws`.

## 5. HTML report: `check --html <file>`

- With `--html`, after connecting to the VM service and before the probe runs, the CLI takes a screenshot:
  Android `adb -s <device> exec-out screencap -p` (PNG on stdout); iOS `xcrun simctl io <device> screenshot
  --type=png <temp file>`. On failure it prints `a11y: no screenshot: <reason>` to stderr and renders the report
  without one; the exit code stays 0.
- When the PNG's width in pixels divided by `native.screen.scale` differs from `native.screen.width` by more than 2%,
  stderr warns `a11y: screenshot is <w>x<h> px but the screen is <W>x<H> pt at scale <s>; boxes may not align`. PNG
  size comes from the IHDR chunk (bytes 16–23, big-endian).
- One self-contained UTF-8 HTML file: no network requests, no external fonts, scripts or stylesheets. The screenshot
  is embedded as `data:image/png;base64,…`. Every app or engine string is HTML-escaped.
- Content, top to bottom (side by side on wide screens):
  1. Header: app, platform, device, local date and time (`YYYY-MM-DD HH:MM`), count per severity
     (error, warning, info).
  2. The screenshot with one box per finding group. Box position and size in percent of `native.screen` width and
     height. Border colour by the group's worst severity: error red, warning amber, info blue. A numbered badge on
     each box. Without a screenshot, the boxes are drawn on an empty frame with the screen's aspect ratio.
  3. Findings, one entry per group, numbered like its badge. Each finding shows severity, rule, source, WCAG
     (when known) and message. Findings without a rect form a last, unnumbered group "Whole screen".
  4. Transcript: an ordered list of `flutter.transcript`.
- Groups: a finding's target is its `flutterId`; else the Flutter id matched to its `nativePath`; else
  `native:<nativePath>`; else its rect rounded to whole points. Findings with the same target form one group; the
  box is the rect of the group's first finding that has one. Groups are numbered 1..n by worst severity (error
  first), then rect top, then rect left.
- Hovering or focusing a list entry highlights its box and the other way round (small inline script). Without
  JavaScript, boxes and list still show.
- Light and dark colours follow `prefers-color-scheme`.

## 6. Widget-test API: `package:marionette_a11y/testing.dart`

- `A11yAuditGuideline({A11ySeverity failOn = A11ySeverity.error})` extends flutter_test's `AccessibilityGuideline`.
  `evaluate` captures `A11ySnapshot`, runs `A11yAudit.run`, and fails when any finding is at or above `failOn`
  (`warning` fails on errors and warnings). The failure reason lists every finding, one per line:
  `[<severity>] <rule> (WCAG <wcag>) — <message>` plus ` — "<name>" at [l, t, w, h]` when it has a node. An empty
  snapshot fails with `no semantics nodes; call tester.ensureSemantics() first`.
  Usage: `await expectLater(tester, meetsGuideline(const A11yAuditGuideline()));`
- `matchesA11yTranscript(String path, {String locale = 'pl'})`: an `AsyncMatcher` for a `WidgetTester`. The golden
  is UTF-8 text, one announcement per line, ending with a newline.
  - Path resolution as `matchesGoldenFile`: relative to `basedir` when `goldenFileComparator` is a
    `LocalFileComparator`, else to the current directory.
  - When `autoUpdateGoldenFiles` is true (`flutter test --update-goldens`), writes the file (creating directories)
    and passes.
  - Missing file: fails with `golden <path> not found; run flutter test --update-goldens`.
  - Different content: fails with a line diff (`-` expected, `+` actual).
- `testing.dart` does not import `marionette_flutter`. `flutter_test` moves to `dependencies` because `lib/` imports
  it; apps add `marionette_a11y` as a dev dependency to use it.
- Contrast in widget tests: README points to flutter_test's `textContrastGuideline`; no new code.

## 7. Agent skill `skills/a11y-audit/SKILL.md`

- Frontmatter `name: a11y-audit`; `description` starts with "Use when" and names the triggers: checking a Flutter
  app's accessibility on Android or iOS, screen reader (TalkBack, VoiceOver) support, WCAG 2.2, an a11y audit of a
  screen or flow, an HTML accessibility report.
- Body, at most 200 lines: prerequisites and debug-only wiring (never committed); the per-screen loop (navigate with
  marionette, `a11y_audit`, `a11y_snapshot` with a screenshot, `a11y check --html` per platform, fix, re-check until
  no errors, repeat at text scale 2.0); guarding fixes with the widget-test API; what to report to the user; a table
  rule → typical Flutter fix for every rule this repo emits; the limits automation cannot judge.
- The skill lives in this repo. Installing it into a user's skills directory is not part of this milestone.
