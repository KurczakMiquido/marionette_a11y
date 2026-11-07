import 'dart:convert';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

List<FlutterNode> fixtureFlutterNodes() => [
  for (final raw in fixture('flutter_snapshot')['nodes'] as List) FlutterNode.fromJson(raw as Map<String, dynamic>),
];

FlutterNode flutter(
  int id,
  A11yRect rect, {
  String role = 'text',
  String name = '',
  String value = '',
  String hint = '',
  String identifier = '',
  bool header = false,
  bool offscreen = false,
  List<String> actions = const [],
}) => FlutterNode(
  id: id,
  role: role,
  rect: rect,
  name: name,
  value: value,
  hint: hint,
  identifier: identifier,
  header: header,
  offscreen: offscreen,
  actions: actions,
);

NativeNode native(
  String path,
  A11yRect rect, {
  String role = 'other',
  String label = '',
  String value = '',
  String hint = '',
  String identifier = '',
  bool clickable = false,
}) => NativeNode(
  path: path,
  nativeType: 'android.view.View',
  role: role,
  label: label,
  value: value,
  hint: hint,
  identifier: identifier,
  rect: rect,
  focusable: clickable,
  clickable: clickable,
  enabled: true,
  selected: false,
  checked: null,
  heading: false,
);

NativeTree tree(List<NativeNode> nodes, {List<NativeIssue> issues = const []}) => NativeTree(
  platform: 'android',
  device: 'emulator-5580',
  app: 'dev.example',
  screen: const NativeScreen(width: 400, height: 800, scale: 2),
  nodes: nodes,
  issues: issues,
);

const box = A11yRect(0, 0, 100, 100);
const far = A11yRect(300, 600, 50, 50);

List<String> rules(CheckReport report) => [for (final f in report.findings) f.rule];

Map<int, String> matchedPaths(CheckReport report) => {for (final m in report.matches) m.flutterId: m.nativePath};

void main() {
  group('fixtures', () {
    test('android: identifier and rect matches, unmatched Menu, unnamed clickable, ATF issue', () {
      final report = CrossCheck.run(fixtureFlutterNodes(), NativeTree.fromJson(fixture('native_android')));

      expect(
        [for (final m in report.matches) m.toJson()],
        [
          {'flutterId': 1, 'nativePath': '0.3', 'by': 'rect'},
          {'flutterId': 2, 'nativePath': '0.0', 'by': 'identifier'},
          {'flutterId': 3, 'nativePath': '0.1', 'by': 'identifier'},
        ],
      );
      expect(
        [for (final f in report.findings) f.toJson()],
        [
          {
            'rule': 'not-exposed',
            'source': 'crosscheck',
            'severity': 'error',
            'message': 'Flutter node 5 "Menu" (button) at [330, 60, 44, 44] has no native counterpart',
            'flutterId': 5,
            'rect': [330.0, 60.0, 44.0, 44.0],
          },
          {
            'rule': 'native-unnamed',
            'source': 'crosscheck',
            'severity': 'error',
            'message': 'Clickable android.view.View at [340, 20, 48, 48] has no label, value or hint',
            'nativePath': '0.2',
            'rect': [340.0, 20.0, 48.0, 48.0],
          },
          {
            'rule': 'TouchTargetSizeCheck',
            'source': 'atf',
            'severity': 'error',
            'message': 'View is too small to touch',
            'nativePath': '0.2',
            'rect': [340.0, 20.0, 48.0, 48.0],
          },
        ],
      );
    });

    test('ios: shifted title is not exposed, unnamed Menu button is a name mismatch', () {
      final report = CrossCheck.run(fixtureFlutterNodes(), NativeTree.fromJson(fixture('native_ios')));

      expect(matchedPaths(report), {2: '0.0', 3: '0.1', 5: '0.2'});
      expect(rules(report), ['not-exposed', 'name-mismatch', 'native-unnamed', 'sufficientElementDescription']);
      final mismatch = report.findings[1];
      expect(mismatch.flutterId, 5);
      expect(mismatch.nativePath, '0.2');
      expect(mismatch.severity, 'warning');
      expect(mismatch.message, 'Flutter name "Menu" differs from native label ""');
      final apple = report.findings[3];
      expect(apple.source, 'apple');
      expect(apple.flutterId, 5, reason: 'issue node 0.2 is matched to Flutter node 5');
    });
  });

  group('matching', () {
    test('identifier match wins over a better rect', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'Save', identifier: 'save'),
      ], tree([native('0.0', far, label: 'Save', identifier: 'save'), native('0.1', box, label: 'Save')]));

      expect(
        [for (final m in report.matches) m.toJson()],
        [
          {'flutterId': 1, 'nativePath': '0.0', 'by': 'identifier'},
        ],
      );
    });

    test('an earlier rect match does not take a node another Flutter node names by identifier', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
        flutter(2, far, name: 'B', identifier: 'b'),
      ], tree([native('0.0', box, label: 'B', identifier: 'b'), native('0.1', const A11yRect(0, 0, 100, 80))]));

      expect(matchedPaths(report), {1: '0.1', 2: '0.0'});
    });

    test('an empty identifier never matches by identifier', () {
      final report = CrossCheck.run([flutter(1, far, name: 'A')], tree([native('0.0', box, label: 'A')]));

      expect(report.matches, isEmpty);
    });

    test('rect IoU of exactly 0.6 matches', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
      ], tree([native('0.0', const A11yRect(0, 0, 100, 60), label: 'A')]));

      expect(report.matches.single.by, 'rect');
    });

    test('rect IoU below 0.6 does not match', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
      ], tree([native('0.0', const A11yRect(0, 0, 100, 59), label: 'A')]));

      expect(report.matches, isEmpty);
      expect(rules(report), ['not-exposed']);
    });

    test('the highest IoU wins', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
      ], tree([native('0.0', const A11yRect(0, 0, 100, 70)), native('0.1', const A11yRect(0, 0, 100, 90))]));

      expect(matchedPaths(report), {1: '0.1'});
    });

    test('each native node matches one Flutter node only', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
        flutter(2, box, name: 'B'),
      ], tree([native('0.0', box, label: 'A')]));

      expect(matchedPaths(report), {1: '0.0'});
      expect(report.findings.single.rule, 'not-exposed');
      expect(report.findings.single.flutterId, 2);
    });

    test('each native node matches one Flutter node only, also by identifier', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A', identifier: 'x'),
        flutter(2, far, name: 'A', identifier: 'x'),
      ], tree([native('0.0', box, label: 'A', identifier: 'x')]));

      expect(matchedPaths(report), {1: '0.0'});
    });

    test('equal IoU prefers a role compatible with the Flutter node', () {
      final report = CrossCheck.run([
        flutter(1, box, role: 'button', name: 'A'),
      ], tree([native('0', box), native('0.0', box, role: 'button', label: 'A'), native('0.0.0', box)]));

      expect(matchedPaths(report), {1: '0.0'});
    });

    test('equal IoU and role compatibility prefer the deepest native node', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A'),
      ], tree([native('0', box), native('0.0', box), native('0.0.0', box), native('0.1', box)]));

      expect(matchedPaths(report), {1: '0.0.0'});
    });

    test('role compatibility covers toggle/switch, header and tappable nodes shown as buttons', () {
      // The compatible candidate is the shallower one, so only role compatibility can pick it.
      CheckReport single(FlutterNode node, String nativeRole) =>
          CrossCheck.run([node], tree([native('0', box, role: nativeRole, label: 'A'), native('0.0', box)]));

      expect(matchedPaths(single(flutter(1, box, role: 'toggle', name: 'A'), 'switch')), {1: '0'});
      expect(matchedPaths(single(flutter(1, box, name: 'A', header: true), 'header')), {1: '0'});
      expect(matchedPaths(single(flutter(1, box, name: 'A', actions: ['tap']), 'button')), {1: '0'});
      expect(matchedPaths(single(flutter(1, box, role: 'button', name: 'A'), 'mystery')), {1: '0.0'});
    });

    test('offscreen Flutter nodes are neither matched nor reported', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'A', offscreen: true, actions: ['tap']),
      ], tree([native('0.0', box, label: 'A')]));

      expect(report.matches, isEmpty);
      expect(report.findings, isEmpty);
    });
  });

  group('not-exposed', () {
    for (final (what, node) in [
      ('a name', flutter(1, box, name: 'A')),
      ('a value', flutter(1, box, value: 'v')),
      ('a hint', flutter(1, box, hint: 'h')),
      ('a tap action', flutter(1, box, role: 'button', actions: ['tap'])),
    ]) {
      test('fires for an unmatched node with $what', () {
        final report = CrossCheck.run([node], tree([native('0', far)]));

        final finding = report.findings.single;
        expect(finding.rule, 'not-exposed');
        expect(finding.source, 'crosscheck');
        expect(finding.severity, 'error');
        expect(finding.flutterId, 1);
        expect(finding.nativePath, isNull);
        expect(finding.rect, box);
      });
    }

    test('describes an unnamed node by value, hint or role', () {
      String message(FlutterNode node) => CrossCheck.run([node], tree([])).findings.single.message;

      expect(message(flutter(7, box, role: 'textField', value: 'v')), contains('Flutter node 7 value "v" (textField)'));
      expect(message(flutter(7, box, hint: 'h')), contains('Flutter node 7 hint "h" (text)'));
      expect(message(flutter(7, box, role: 'button', actions: ['tap'])), contains('Flutter node 7 (button)'));
    });

    test('does not fire for an unnamed node without a tap action', () {
      final report = CrossCheck.run([
        flutter(1, box, actions: ['scrollUp']),
      ], tree([native('0', far)]));

      expect(report.findings, isEmpty);
    });

    test('does not fire for a matched node', () {
      final report = CrossCheck.run([flutter(1, box, name: 'A')], tree([native('0.0', box, label: 'A')]));

      expect(report.findings, isEmpty);
    });
  });

  group('name-mismatch', () {
    CheckReport check(String flutterName, {String label = '', String hint = ''}) =>
        CrossCheck.run([flutter(1, box, name: flutterName)], tree([native('0.0', box, label: label, hint: hint)]));

    test('fires when the names differ', () {
      final finding = check('Save', label: 'Submit').findings.single;

      expect(finding.rule, 'name-mismatch');
      expect(finding.source, 'crosscheck');
      expect(finding.severity, 'warning');
      expect(finding.flutterId, 1);
      expect(finding.nativePath, '0.0');
      expect(finding.rect, box);
      expect(finding.message, 'Flutter name "Save" differs from native label "Submit"');
    });

    test('does not fire when the names are equal after normalization', () {
      expect(check('  Save\n  the   Form. ', label: 'save the form;').findings, isEmpty);
    });

    test('falls back to the native hint when the label is empty', () {
      expect(check('E-mail', hint: 'E-mail').findings, isEmpty);
      expect(
        check('E-mail', hint: 'Email').findings.single.message,
        'Flutter name "E-mail" differs from native hint "Email"',
      );
    });

    test('does not fall back to the hint when the label is set', () {
      expect(check('E-mail', label: 'Mail', hint: 'E-mail').findings.single.rule, 'name-mismatch');
    });

    test('fires when Flutter has no name but the native node has a label', () {
      expect(check('', label: 'Extra').findings.single.rule, 'name-mismatch');
    });
  });

  group('native-unnamed', () {
    test('fires for a clickable node with no label, value or hint', () {
      final report = CrossCheck.run([], tree([native('0', box), native('0.0', far, role: 'button', clickable: true)]));

      final finding = report.findings.single;
      expect(finding.rule, 'native-unnamed');
      expect(finding.source, 'crosscheck');
      expect(finding.severity, 'error');
      expect(finding.nativePath, '0.0');
      expect(finding.flutterId, isNull);
      expect(finding.rect, far);
    });

    test('carries the Flutter id when the native node is matched', () {
      final report = CrossCheck.run([
        flutter(1, far, role: 'button', actions: ['tap']),
      ], tree([native('0.0', far, role: 'button', clickable: true)]));

      expect(report.findings.single.rule, 'native-unnamed');
      expect(report.findings.single.flutterId, 1);
    });

    for (final (what, node) in [
      ('a label', native('0', box, clickable: true, label: 'A')),
      ('a value', native('0', box, clickable: true, value: 'v')),
      ('a hint', native('0', box, clickable: true, hint: 'h')),
      ('no click action', native('0', box)),
    ]) {
      test('does not fire for a node with $what', () {
        expect(CrossCheck.run([], tree([node])).findings, isEmpty);
      });
    }

    test('does not fire when a descendant has a label', () {
      final report = CrossCheck.run(
        [],
        tree([native('0', box, clickable: true), native('0.0', box), native('0.0.0', box, label: 'Inside')]),
      );

      expect(report.findings, isEmpty);
    });

    test('a sibling whose path only starts with the same digits is not a descendant', () {
      final nodes = [for (var i = 0; i <= 10; i++) native('0.$i', box)];
      nodes[1] = native('0.1', box, clickable: true);
      nodes[10] = native('0.10', box, label: 'Not inside');

      expect(rules(CrossCheck.run([], tree(nodes))), ['native-unnamed']);
    });
  });

  group('native issues', () {
    test('pass through with their source, check, severity, node and rect', () {
      const issueRect = A11yRect(1, 2, 3, 4);
      final report = CrossCheck.run(
        [flutter(1, box, name: 'A')],
        tree(
          [native('0.0', box, label: 'A')],
          issues: const [
            NativeIssue(
              source: 'apple',
              check: 'hitRegion',
              severity: 'error',
              message: 'Too small',
              nodePath: '0.0',
              rect: issueRect,
            ),
            NativeIssue(source: 'atf', check: 'SomeNewCheck', severity: 'notice', message: 'Hm'),
          ],
        ),
      );

      expect(
        [for (final f in report.findings) f.toJson()],
        [
          {
            'rule': 'hitRegion',
            'source': 'apple',
            'severity': 'error',
            'message': 'Too small',
            'flutterId': 1,
            'nativePath': '0.0',
            'rect': [1.0, 2.0, 3.0, 4.0],
          },
          {'rule': 'SomeNewCheck', 'source': 'atf', 'severity': 'notice', 'message': 'Hm'},
        ],
      );
    });
  });

  group('normalize', () {
    test('lowercases, collapses whitespace, trims and strips trailing .,;:', () {
      expect(CrossCheck.normalize('  Umów\n\t WIZYTĘ  '), 'umów wizytę');
      expect(CrossCheck.normalize('Save.'), 'save');
      expect(CrossCheck.normalize('Save ,;: '), 'save');
      expect(CrossCheck.normalize('Save!'), 'save!');
      expect(CrossCheck.normalize('a.b'), 'a.b');
      expect(CrossCheck.normalize(''), '');
    });
  });

  group('report', () {
    test('serializes as a11y-check/v1', () {
      final nativeJson = fixture('native_android');
      final snapshot = fixture('flutter_snapshot');
      final report = CrossCheck.run(fixtureFlutterNodes(), NativeTree.fromJson(nativeJson));

      final json = jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>;
      expect(json.keys, ['schema', 'platform', 'app', 'flutter', 'native', 'matches', 'findings']);
      expect(json['schema'], 'a11y-check/v1');
      expect(json['platform'], 'android');
      expect(json['app'], 'dev.poc.marionette_a11y_example');
      expect(json['flutter'], {'nodes': snapshot['nodes']});
      expect(json['native'], nativeJson);
      expect(json['matches'], hasLength(3));
      expect(json['findings'], hasLength(3));
    });

    test('summary prints counts per severity, then one line per finding', () {
      final report = CrossCheck.run(
        [
          flutter(1, box, name: 'Save', actions: ['tap']),
        ],
        tree(
          [native('0.0', box, label: 'Submit')],
          issues: const [
            NativeIssue(source: 'atf', check: 'TextContrastCheck', severity: 'info', message: 'Low\n  contrast.'),
            NativeIssue(source: 'atf', check: 'OddCheck', severity: 'notice', message: 'Odd'),
          ],
        ),
      );

      expect(
        report.summary(),
        'error: 0, warning: 1, info: 1, notice: 1\n'
        '[warning] name-mismatch — Flutter name "Save" differs from native label "Submit"\n'
        '[info] TextContrastCheck — Low contrast.\n'
        '[notice] OddCheck — Odd\n',
      );
    });

    test('summary of a clean report has only the counts', () {
      expect(CrossCheck.run([], tree([])).summary(), 'error: 0, warning: 0, info: 0\n');
    });
  });
}
