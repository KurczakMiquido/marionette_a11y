# marionette_a11y

PoC: Flutter's semantics tree as marionette MCP tools, so an agent can check what a screen reader announces.

| MCP tool | What it returns |
|---|---|
| `a11y_snapshot` | `transcript` (what TalkBack reads, in swipe order) plus semantics `nodes` |
| `a11y_audit` | WCAG 2.2 findings: `missing-name`, `missing-role`, `target-size`, `generic-name`, `role-in-name`, `duplicate-name`, `no-heading` |

## Wire it in (debug only, never commit to the app)

```yaml
dependencies:
  marionette_flutter: 0.6.0
  marionette_a11y:
    path: ../marionette_a11y
```

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
3. `set_device_config` with text scale 2.0, repeat (WCAG 1.4.4).
4. After each `tap`, snapshot again: a state change must show up in the transcript.

## Limits

- Rules cover a fraction of WCAG. A hint-only `TextField` is invisible here: Flutter puts `hintText` into the label.
- The transcript approximates TalkBack. Calibrate against a real TalkBack speech log before trusting wording.
- No VoiceOver: it does not run in the iOS simulator.

## Run

```bash
fvm flutter test && (cd example && fvm flutter test)
```
