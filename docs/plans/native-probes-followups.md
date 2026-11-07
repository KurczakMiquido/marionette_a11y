# Native probes: follow-ups after milestone 1

Deferred during review; none blocks use. Next milestone candidates first.

## Next milestone
Done in milestone 2 (`docs/specs/report-and-testing.md`) except CI pipeline files; remaining items in
`docs/plans/report-and-testing-followups.md`.

- HTML report with screenshots and boxes from real rects (Android and iOS).
- Agent skill `a11y-audit` driving the loop (marionette MCP + `a11y check`).
- Role-comparison rule: a tappable Flutter node exposed natively as plain text (title with a back-arrow tap target).
- Flutter snapshot exposes `tooltip`, so iOS `label\ntooltip` and Android tooltip-with-value names compare correctly.
- Contrast from the Flutter side; CI goldens of the screen-reader transcript.

## Deferred minor findings
- (task 1) cli/.gitignore ignores pubspec.lock although the package ships an executable
- (task 1) no test for checked:true / heading:true / issue rect non-null
- (task 2) role matched on class simple name only; AppCompat/Material subclasses (AppCompatEditText...) fall to button — add isEditable/isCheckable fallbacks (Flutter itself uses plain android.widget classes)
- (task 2) nodePath fallback may attribute an issue on a hidden node to a same-bounds visible parent
- (task 2) run.sh:311-314 empty instrument output + pipefail can exit without the one-line reason
- (task 2) run.sh staleness misses gradle-wrapper.properties changes and deleted sources
- (task 2) run.sh:306/319 $package unquoted in adb remote command; stale out.json left on pull failure
- (task 3) run.sh:461 `simctl list | grep -q` under pipefail can SIGPIPE into a false "not booted"; UDID match case-sensitive
- (task 3) run.sh:489 partial out.json left when base64 decode fails
- (task 3) issue with null frame → [0,0,0,0] can resolve to a wrong nodePath
- (task 3) device falls back to "" if SIMULATOR_UDID missing; run.sh could pass the UDID explicitly
- (task 3) staleness find also trips on .xcodeproj dir mtime; no lock for concurrent runs
- (task 4) normalization strips [\s.,;:]+$ before trim (also repeated punctuation) — sensible, pinned by test; spec line should say so
- (task 4) no timeout on getVM/getIsolate/callServiceExtension after connect — paused isolate hangs check
- (task 4) tie-break tests miss "higher IoU beats compatible role" and equal-depth pre-order fallback
- (task 4) webSocketUri appends ws to an http URI that already ends in /ws
- (task 4) no runner test for probe failure after VM connect; temp-dir delete in finally can mask the real error
- (final) Android route-scope skip also silences a Flutter name on a non-focusable node with an empty native label.
- (final) Parallel iOS runs isolated by per-run dirs but never exercised on two simulators at once.
- (final) Failed iOS runs keep their build/run.* directory with the log; nothing prunes them.
