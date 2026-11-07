import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

CheckReport _report(List<Finding> findings, {List<NodeMatch> matches = const []}) => CheckReport(
  flutterNodes: const [],
  native: const NativeTree(
    platform: 'android',
    device: 'emulator-5580',
    app: 'dev.app',
    screen: NativeScreen(width: 400, height: 800, scale: 2),
    nodes: [],
    issues: [],
  ),
  matches: matches,
  findings: findings,
);

Finding _finding(String rule, {String severity = 'warning', int? flutterId, String? nativePath, A11yRect? rect}) =>
    Finding(
      rule: rule,
      source: 'crosscheck',
      severity: severity,
      message: rule,
      flutterId: flutterId,
      nativePath: nativePath,
      rect: rect,
    );

List<List<String>> _rules(List<FindingGroup> groups) => [
  for (final g in groups) [for (final f in g.findings) f.rule],
];

void main() {
  test('findings with the same flutterId form one group boxed by the first rect', () {
    final groups = FindingGroup.of(
      _report([
        _finding('a', flutterId: 1),
        _finding('b', flutterId: 1, rect: const A11yRect(10, 20, 30, 40)),
        _finding('c', flutterId: 1, rect: const A11yRect(0, 0, 1, 1)),
        _finding('d', flutterId: 2, rect: const A11yRect(10, 20, 30, 40)),
      ]),
    );

    expect(_rules(groups), [
      ['a', 'b', 'c'],
      ['d'],
    ]);
    expect(groups.first.flutterId, 1);
    expect(groups.first.rect, const A11yRect(10, 20, 30, 40));
  });

  test('a nativePath joins the group of the Flutter node it was matched to', () {
    final groups = FindingGroup.of(
      _report(
        [
          _finding('flutter', flutterId: 7, rect: const A11yRect(10, 10, 10, 10)),
          _finding('native', nativePath: '0.1', rect: const A11yRect(11, 11, 10, 10)),
        ],
        matches: [const NodeMatch(flutterId: 7, nativePath: '0.1', by: NodeMatch.byRect)],
      ),
    );

    expect(_rules(groups), [
      ['flutter', 'native'],
    ]);
    expect(groups.single.flutterId, 7);
  });

  test('an unmatched nativePath groups by the native path alone', () {
    final groups = FindingGroup.of(
      _report([
        _finding('a', nativePath: '0.2', rect: const A11yRect(10, 10, 10, 10)),
        _finding('b', nativePath: '0.2', rect: const A11yRect(50, 50, 10, 10)),
        _finding('c', nativePath: '0.3', rect: const A11yRect(10, 10, 10, 10)),
      ]),
    );

    expect(_rules(groups), [
      ['a', 'b'],
      ['c'],
    ]);
    expect(groups.first.flutterId, isNull);
    expect(groups.first.nativePath, '0.2');
  });

  test('findings with only a rect group by the rect rounded to whole points', () {
    final groups = FindingGroup.of(
      _report([
        _finding('a', rect: const A11yRect(10.2, 20.4, 30, 40)),
        _finding('b', rect: const A11yRect(9.8, 19.6, 30.3, 39.7)),
        _finding('c', rect: const A11yRect(10.2, 20.4, 31, 40)),
      ]),
    );

    expect(_rules(groups), [
      ['a', 'b'],
      ['c'],
    ]);
    expect(groups.first.rect, const A11yRect(10.2, 20.4, 30, 40));
  });

  test('findings without a rect form the last, unnumbered group', () {
    final groups = FindingGroup.of(
      _report([
        _finding('screen', severity: 'error'),
        _finding('boxed', rect: const A11yRect(1, 1, 1, 1)),
        // A target without any rect has no box to draw.
        _finding('rectless node', flutterId: 3),
        _finding('rectless native', nativePath: '0.9'),
      ]),
    );

    expect(_rules(groups), [
      ['boxed'],
      ['screen', 'rectless node', 'rectless native'],
    ]);
    expect(groups.first.number, 1);
    expect(groups.last.number, isNull);
    expect(groups.last.rect, isNull);
    expect(groups.last.severity, 'error');
  });

  test('no whole-screen group when every finding has a box', () {
    final groups = FindingGroup.of(_report([_finding('a', rect: const A11yRect(1, 1, 1, 1))]));

    expect(groups.map((g) => g.number), [1]);
  });

  test('groups are numbered by worst severity, then top, then left', () {
    final groups = FindingGroup.of(
      _report([
        _finding('info top', severity: 'info', rect: const A11yRect(0, 0, 5, 5)),
        _finding('warning top', rect: const A11yRect(0, 0, 6, 6)),
        _finding('error low', severity: 'error', rect: const A11yRect(0, 300, 5, 5)),
        _finding('error right', severity: 'error', rect: const A11yRect(50, 100, 5, 5)),
        _finding('error left', severity: 'error', rect: const A11yRect(10, 100, 5, 5)),
        // Worst severity counts: a warning box with an error in it ranks with the errors.
        _finding('mixed', flutterId: 9, rect: const A11yRect(0, 200, 5, 5)),
        _finding('mixed error', severity: 'error', flutterId: 9),
      ]),
    );

    expect(groups.map((g) => g.findings.first.rule), [
      'error left',
      'error right',
      'mixed',
      'error low',
      'warning top',
      'info top',
    ]);
    expect(groups.map((g) => g.number), [1, 2, 3, 4, 5, 6]);
    expect(groups.map((g) => g.severity), ['error', 'error', 'error', 'error', 'warning', 'info']);
  });

  test('no findings give no groups', () {
    expect(FindingGroup.of(_report([])), isEmpty);
  });
}
