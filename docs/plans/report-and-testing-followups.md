# Milestone 2: follow-ups

Deferred during review; none blocks use.

## Next
- Re-test `skills/a11y-audit/SKILL.md` with a fresh agent: the final text (after the review fixes) was never run by one.
- Try the skill on a real app screen with a bottom navigation bar: the report's fitted screenshot was checked only on
  the example screens.
- Package split: `testing.dart` keeps clear of `marionette_flutter`, but the package still depends on it; a separate
  core package would let apps add only the test API.

## Deferred minor findings
- (task 1) cli/test/cross_check_test.dart group title "ios compares the name alone" is stale; no iOS test for a real
  mismatch on a tooltip-only node.
- (task 2) WCAG table tests skip 5 ATF and 2 Apple checks; the iOS role-mismatch test reuses an Android nativeType.
- (task 3) only the audit call has a timeout test; `_within` also catches a TimeoutException thrown by the call itself.
- (task 4) `_number` formatter repeated in three files; FindingGroup.severity throws on an empty group; the
  highlight script has no automated test; long string/CSS lines in the HTML renderer.
- (task 5) golden paths resolve as URIs, like matchesGoldenFile (spaces and % resolve oddly).
- (task 6) the skill runs `fvm` unconditionally; prerequisites do not require it.
- (final) the unreadable-screenshot test uses chmod 000 and passes vacuously as root.
