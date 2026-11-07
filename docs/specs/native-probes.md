# Native accessibility probes: spec

Goal: Flutter developers check what TalkBack (Android) and VoiceOver (iOS) actually receive, not only what
Flutter's semantics tree says. A probe per platform reads the native accessibility tree of a running app and
runs the platform's official checks. A Dart CLI joins that with the Flutter semantics snapshot from
`marionette_a11y` and reports where they disagree.

## Scope (milestone 1)

- Android emulator and iOS simulator. Physical devices are out of scope.
- No installs beyond what a Flutter developer already has: Android SDK + Gradle, Xcode. Maven dependencies are fine.
- The target app runs and is already on the screen to check. Probes never launch, relaunch or navigate it.
- Out of scope: HTML report, agent skill, contrast from Flutter side, CI goldens. They come in later milestones.

## Components

| Path | What | Language |
|---|---|---|
| `probes/android/` | Instrumentation APK. UiAutomation reads the target app's `AccessibilityNodeInfo` tree; Google Accessibility Test Framework (ATF) runs its checks with a screenshot. | Kotlin, Gradle |
| `probes/ios/` | UI testing bundle. `XCUIApplication(bundleIdentifier:)` snapshots the target app's tree; `performAccessibilityAudit` runs Apple's checks. | Swift, Xcode |
| `cli/` | Pure Dart package `a11y_cli`, executable `a11y`. Runs a probe, fetches the Flutter snapshot over the VM service, cross-checks both. | Dart |

Each probe has `run.sh <device> <appId> <out.json>`: builds the probe if needed, runs it, writes `out.json` in the
format below, exits non-zero with a one-line reason on failure.

- Android `<device>`: adb serial, e.g. `emulator-5580`. `<appId>`: package name.
- iOS `<device>`: simulator UDID. `<appId>`: bundle identifier.

## Native tree format: `a11y-native/v1`

```json
{
  "schema": "a11y-native/v1",
  "platform": "android",
  "device": "emulator-5580",
  "app": "dev.poc.marionette_a11y_example",
  "screen": { "width": 411.4, "height": 914.3, "scale": 2.625 },
  "nodes": [ NativeNode ],
  "issues": [ NativeIssue ]
}
```

`screen` is in logical points; `scale` is physical pixels per point (Android: `densityDpi / 160`).

`nodes` lists the target app's accessibility tree in pre-order (parent before children, children in platform
order). Only the target app's windows are included.

### NativeNode

| Field | Type | Android source | iOS source |
|---|---|---|---|
| `path` | string | index path from the window root, `"0"`, `"0.2"`, `"0.2.1"` | same, from the app root |
| `nativeType` | string | `className` | `XCUIElement.ElementType` name, e.g. `"button"` |
| `role` | enum | from className and flags, see below | from element type |
| `label` | string | `contentDescription`, else `text` (unless editable) | `label` |
| `value` | string | `text` when editable, else `stateDescription` | `value` as string |
| `hint` | string | `hintText` | `placeholderValue` |
| `identifier` | string | `viewIdResourceName` | `identifier` |
| `rect` | [left, top, width, height] | `getBoundsInScreen` / scale | `frame` |
| `focusable` | bool | `isFocusable \|\| isScreenReaderFocusable` | element type is not `other`, or label is non-empty |
| `clickable` | bool | `isClickable \|\| isLongClickable` | element type is interactive (button, link, textField, secureTextField, switch, toggle, slider, cell, tab, checkBox, radioButton, menuItem, segmentedControl, stepper, searchField) |
| `enabled` | bool | `isEnabled` | `isEnabled` |
| `selected` | bool | `isSelected` | `isSelected` |
| `checked` | bool or null | `isCheckable ? isChecked : null` | `null` |
| `heading` | bool or null | `isHeading` | `null` (XCUITest does not expose traits) |

All strings are present (empty when missing). Rect numbers are rounded to one decimal.

`role` is one of: `button`, `textField`, `checkbox`, `radio`, `switch`, `slider`, `link`, `image`, `header`, `tab`,
`text`, `other`.

- Android: `EditText` → `textField`; `CheckBox` → `checkbox`; `RadioButton` → `radio`; `Switch`/`ToggleButton` →
  `switch`; `SeekBar` → `slider`; `ImageView` → `image`; `Button`/`ImageButton` or clickable with no better match →
  `button`; `isHeading` → `header`; otherwise `text` when it has a label, else `other`.
- iOS: `button` → `button`; `textField`/`secureTextField`/`searchField`/`textView` → `textField`; `switch`/`toggle` →
  `switch`; `slider` → `slider`; `link` → `link`; `image` → `image`; `tab` → `tab`; `checkBox` → `checkbox`;
  `radioButton` → `radio`; `staticText` → `text`; otherwise `other`.

### NativeIssue

| Field | Type | Meaning |
|---|---|---|
| `source` | `"atf"` or `"apple"` | which engine reported it |
| `check` | string | ATF check class simple name, or Apple `XCUIAccessibilityAuditType` name (`contrast`, `elementDetection`, `hitRegion`, `sufficientElementDescription`, `dynamicType`, `textClipped`, `trait`) |
| `severity` | `"error"`, `"warning"` or `"info"` | ATF: ERROR/WARNING/INFO. Apple: `error` for every issue |
| `message` | string | engine's human-readable text |
| `nodePath` | string or null | `path` of the node it refers to, when it can be resolved |
| `rect` | [l, t, w, h] or null | logical points |

ATF results of type `NOT_RUN` and `RESOLVED` are dropped. `nodePath` and `rect` are always present, `null` when
unknown.

## Flutter snapshot

`ext.flutter.a11y.snapshot` from `marionette_a11y`, called with `includeRects=true`, returns
`{ transcript: [...], nodes: [FlutterNode] }`. FlutterNode keys: `id` (int), `role`, `name`, `value`, `hint`,
`identifier`, `header`, `offscreen`, `checked`, `toggled`, `selected`, `enabled`, `expanded`, `actions` (list of
names), `rect` ([l, t, w, h] logical). Optional keys are absent when empty/false.

## Cross-check: `a11y-check/v1`

```json
{
  "schema": "a11y-check/v1",
  "platform": "ios",
  "app": "dev.poc.marionetteA11yExample",
  "flutter": { "nodes": [ FlutterNode ] },
  "native": { a11y-native/v1 document },
  "matches": [ { "flutterId": 12, "nativePath": "0.3.1", "by": "identifier" } ],
  "findings": [ Finding ]
}
```

Matching, per on-screen Flutter node, in Flutter traversal order:

1. Same non-empty `identifier` → match (`by: "identifier"`).
2. Otherwise the unmatched native node with the highest rect IoU, if IoU ≥ 0.6 → match (`by: "rect"`).

Each native node matches at most one Flutter node.

Finding: `{ rule, source, severity, message, flutterId?, nativePath?, rect? }`. Absent optional keys are left out,
not written as `null`.

| rule | source | severity | when |
|---|---|---|---|
| `not-exposed` | `crosscheck` | error | Flutter node has a name, value or hint, or a `tap` action, and has no native match |
| `name-mismatch` | `crosscheck` | warning | matched, and the normalized Flutter text differs from the normalized native text the platform builds from it, see below |
| `native-unnamed` | `crosscheck` | error | native node is `clickable`, has a non-empty rect, its `label`, `value` and `hint` are empty, and no descendant (path prefix) has a label |
| `<check>` | `atf` / `apple` | issue severity | every NativeIssue, passed through |

`name-mismatch` compares what the screen reader receives, which differs per platform (Flutter 3.44 engine):

- iOS keeps label, value and hint apart (`SemanticsObject.mm`). Flutter `name` is compared with native `label`, or
  with native `hint` when `label` is empty.
- Android joins them (`AccessibilityBridge.java`). A node's content description is its value, label and hint, the
  non-empty ones joined with `", "`; a text field's `hintText` is its label and hint joined the same way, its value
  stays apart; a route scope (`scopesRoute`) gets neither and is not focusable. So native `label` is compared with
  Flutter `value`, `name`, `hint` joined that way, and for a Flutter `textField` native `hint` with `name`, `hint`.
  A native node that is not focusable and has an empty `label` and `hint` is skipped.

Normalize: lowercase, collapse each whitespace run to one space, strip a trailing run of whitespace and `.,;:`
(`[\s.,;:]+$`), trim.

## CLI

```
dart run a11y_cli:a11y native --platform android|ios --device <id> --app <appId> --out native.json
dart run a11y_cli:a11y check  --platform android|ios --device <id> --app <appId> --vm-service <ws uri> --out check.json
```

- `--probes-dir` overrides where `run.sh` scripts are found; default is `../probes` relative to the `cli` package.
- `check` prints a summary: counts per severity, then one line per finding (`[severity] rule — message`).
- Exit code 0 when the command ran, whatever the findings; 1 on a usage or probe failure.
