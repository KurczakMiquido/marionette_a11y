import 'dart:convert';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

import 'test_support.dart';

List<FlutterNode> fixtureFlutterNodes([String name = 'flutter_snapshot']) => [
  for (final raw in fixture(name)['nodes'] as List) FlutterNode.fromJson(raw as Map<String, dynamic>),
];

FlutterNode flutter(
  int id,
  A11yRect rect, {
  String role = 'text',
  String name = '',
  String value = '',
  String hint = '',
  String tooltip = '',
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
  tooltip: tooltip,
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
  bool? focusable,
}) => NativeNode(
  path: path,
  nativeType: 'android.view.View',
  role: role,
  label: label,
  value: value,
  hint: hint,
  identifier: identifier,
  rect: rect,
  focusable: focusable ?? clickable,
  clickable: clickable,
  enabled: true,
  selected: false,
  checked: null,
  heading: false,
);

NativeTree tree(List<NativeNode> nodes, {List<NativeIssue> issues = const [], String platform = 'android'}) =>
    NativeTree(
      platform: platform,
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
    // Booking screen with mistakes, read on emulator-5580 and the iOS simulator, trimmed.
    const android = '0.0.0.0.0.0.0.0';
    const ios = '0.0.0.0.0.0.1.1.1.1.1';

    test('android: identifier and rect matches, a node missing natively, unnamed clickable, ATF issues', () {
      final report = CrossCheck.run(fixtureFlutterNodes(), NativeTree.fromJson(fixture('native_android')));

      expect(
        [for (final m in report.matches) m.toJson()],
        [
          {'flutterId': 37, 'nativePath': '$android.0', 'by': 'rect'},
          {'flutterId': 39, 'nativePath': '$android.2', 'by': 'identifier'},
          {'flutterId': 40, 'nativePath': '$android.3', 'by': 'rect'},
          {'flutterId': 41, 'nativePath': '$android.3.0', 'by': 'rect'},
          {'flutterId': 45, 'nativePath': '$android.5.0', 'by': 'rect'},
        ],
      );
      expect(
        [for (final f in report.findings.take(2)) f.toJson()],
        [
          {
            'rule': 'not-exposed',
            'source': 'crosscheck',
            'severity': 'error',
            'message': 'Flutter node 42 "Lipidogram" (text) at [16, 200, 379, 56] has no native counterpart',
            'flutterId': 42,
            'rect': [16.0, 200.0, 379.0, 56.0],
            'wcag': '4.1.2',
          },
          {
            'rule': 'native-unnamed',
            'source': 'crosscheck',
            'severity': 'error',
            'message': 'Clickable android.widget.Button at [16, 256, 48, 48] has no label, value or hint',
            'flutterId': 45,
            'nativePath': '$android.5.0',
            'rect': [16.0, 256.0, 48.0, 48.0],
            'wcag': '4.1.2',
          },
        ],
      );
      expect(
        [for (final f in report.findings.skip(2)) (f.rule, f.source, f.severity, f.flutterId, f.nativePath)],
        [
          ('SpeakableTextPresentCheck', 'atf', 'error', 45, '$android.5.0'),
          ('TouchTargetSizeCheck', 'atf', 'error', 41, '$android.3.0'),
          ('TextContrastCheck', 'atf', 'warning', 39, '$android.2'),
        ],
      );
    });

    test('ios: shifted title is not exposed, a name that does not reach VoiceOver, Apple issues', () {
      final report = CrossCheck.run(
        fixtureFlutterNodes('flutter_snapshot_ios'),
        NativeTree.fromJson(fixture('native_ios')),
      );

      expect(matchedPaths(report), {38: '$ios.3', 39: '$ios.4.0', 40: '$ios.4.1', 44: '$ios.6.1'});
      expect(rules(report), [
        'not-exposed',
        'name-mismatch',
        'native-unnamed',
        'hitRegion',
        'sufficientElementDescription',
      ]);
      expect(report.findings.first.flutterId, 36);
      final mismatch = report.findings[1];
      expect(mismatch.flutterId, 44);
      expect(mismatch.nativePath, '$ios.6.1');
      expect(mismatch.severity, 'warning');
      expect(mismatch.message, 'Flutter name "Kalendarz" differs from native label ""');
      expect(
        [for (final f in report.findings.skip(2)) (f.source, f.flutterId)],
        [('crosscheck', 44), ('apple', 40), ('apple', 44)],
      );
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
    for (final platform in ['android', 'ios']) {
      CheckReport check(String flutterName, {String label = ''}) => CrossCheck.run([
        flutter(1, box, name: flutterName),
      ], tree([native('0.0', box, label: label, focusable: true)], platform: platform));

      test('$platform: fires when the names differ', () {
        final finding = check('Save', label: 'Submit').findings.single;

        expect(finding.rule, 'name-mismatch');
        expect(finding.source, 'crosscheck');
        expect(finding.severity, 'warning');
        expect(finding.flutterId, 1);
        expect(finding.nativePath, '0.0');
        expect(finding.rect, box);
        expect(finding.message, 'Flutter name "Save" differs from native label "Submit"');
      });

      test('$platform: does not fire when the names are equal after normalization', () {
        expect(check('  Save\n  the   Form. ', label: 'save the form;').findings, isEmpty);
      });

      test('$platform: fires when Flutter has no name but the native node has a label', () {
        expect(check('', label: 'Extra').findings.single.rule, 'name-mismatch');
      });
    }

    group('android compares with what the bridge composes', () {
      List<String> messages(FlutterNode node, NativeNode nativeNode) => [
        for (final f in CrossCheck.run([node], tree([nativeNode])).findings) f.message,
      ];

      test('value, name and hint joined with ", " in the content description', () {
        final slider = flutter(1, box, role: 'slider', name: 'Volume', value: '50%');
        final progress = flutter(1, box, name: 'Upload', value: '40', hint: 'Updates live');

        expect(messages(slider, native('0', box, role: 'slider', label: '50%, Volume', focusable: true)), isEmpty);
        expect(messages(progress, native('0', box, label: '40, Upload, Updates live', focusable: true)), isEmpty);
        expect(messages(slider, native('0', box, role: 'slider', label: 'Volume, 50%', focusable: true)), [
          'Flutter value + name "50%, Volume" differs from native label "Volume, 50%"',
        ]);
      });

      test('a value-only node', () {
        final node = flutter(1, box, value: '40');

        expect(messages(node, native('0', box, label: '40', focusable: true)), isEmpty);
        expect(messages(node, native('0', box, label: '41', focusable: true)), [
          'Flutter value "40" differs from native label "41"',
        ]);
      });

      test('a text field: label and hint joined in the hint text, the value apart', () {
        final field = flutter(1, box, role: 'textField', name: 'E-mail', value: 'a@b.c', hint: 'Work address');
        NativeNode editText(String hint) =>
            native('0', box, role: 'textField', value: 'a@b.c', hint: hint, clickable: true);

        expect(messages(field, editText('E-mail, Work address')), isEmpty);
        expect(messages(field, editText('E-mail')), [
          'Flutter name + hint "E-mail, Work address" differs from native hint "E-mail"',
        ]);
      });

      test('a route scope: not focusable, no label and no hint', () {
        final dialog = flutter(1, box, name: 'Alert');

        expect(messages(dialog, native('0', box)), isEmpty);
        expect(messages(dialog, native('0', box, focusable: true)), [
          'Flutter name "Alert" differs from native label ""',
        ], reason: 'a focusable node without a label is not a route scope');
      });

      test('label and tooltip: the tooltip stays out of the content description', () {
        final node = flutter(1, box, name: 'Zapisz', tooltip: 'Zapisuje ustawienia');

        expect(messages(node, native('0', box, label: 'Zapisz', focusable: true)), isEmpty);
      });

      test('tooltip only: the content description is the tooltip, even with an empty value, label and hint', () {
        final node = flutter(1, box, name: 'Zapisuje', tooltip: 'Zapisuje');

        expect(messages(node, native('0', box, label: 'Zapisuje', focusable: true)), isEmpty);
        expect(messages(node, native('0', box, label: 'Inne', focusable: true)), [
          'Flutter tooltip "Zapisuje" differs from native label "Inne"',
        ]);
      });

      test('value and tooltip without a label: the value alone', () {
        final node = flutter(1, box, name: 'Głośność', value: '50%', tooltip: 'Głośność');

        expect(messages(node, native('0', box, label: '50%', focusable: true)), isEmpty);
      });

      test('a text field ignores the tooltip in its hint text', () {
        final field = flutter(1, box, role: 'textField', name: 'E-mail', tooltip: 'Adres');

        expect(messages(field, native('0', box, role: 'textField', hint: 'E-mail', clickable: true)), isEmpty);
      });

      test('a real label difference still fires', () {
        expect(
          messages(flutter(1, box, name: 'Save', actions: ['tap']), native('0', box, label: 'Submit', clickable: true)),
          ['Flutter name "Save" differs from native label "Submit"'],
        );
      });
    });

    group('ios compares the name alone', () {
      CheckReport check(FlutterNode node, NativeNode nativeNode) =>
          CrossCheck.run([node], tree([nativeNode], platform: 'ios'));

      test('the value and hint stay apart from the label', () {
        final slider = flutter(1, box, role: 'slider', name: 'Volume', value: '50%', hint: 'Adjust');

        expect(
          check(slider, native('0', box, role: 'slider', label: 'Volume', value: '50%', focusable: true)).findings,
          isEmpty,
        );
        expect(
          check(
            slider,
            native('0', box, role: 'slider', label: '50%, Volume', focusable: true),
          ).findings.single.message,
          'Flutter name "Volume" differs from native label "50%, Volume"',
        );
      });

      test('an unlabeled node that is not focusable still fires', () {
        expect(check(flutter(1, box, name: 'Alert'), native('0', box)).findings.single.rule, 'name-mismatch');
      });

      test('falls back to the native hint when the label is empty', () {
        final field = flutter(1, box, name: 'E-mail');

        expect(check(field, native('0', box, hint: 'E-mail')).findings, isEmpty);
        expect(
          check(field, native('0', box, hint: 'Email')).findings.single.message,
          'Flutter name "E-mail" differs from native hint "Email"',
        );
      });

      test('label and tooltip joined with a newline match the native label', () {
        final node = flutter(1, box, name: 'Zapisz', tooltip: 'Zapisuje ustawienia');

        expect(check(node, native('0', box, label: 'Zapisz\nZapisuje ustawienia', focusable: true)).findings, isEmpty);
      });

      test('a tooltip alone matches the native label', () {
        final node = flutter(1, box, name: 'Zapisuje', tooltip: 'Zapisuje');

        expect(check(node, native('0', box, label: 'Zapisuje', focusable: true)).findings, isEmpty);
      });

      test('a mismatch names the tooltip when it took part', () {
        final node = flutter(1, box, name: 'Zapisz', tooltip: 'Zapisuje ustawienia');

        expect(
          check(node, native('0', box, label: 'Zapisz', focusable: true)).findings.single.message,
          'Flutter name + tooltip "Zapisz\nZapisuje ustawienia" differs from native label "Zapisz"',
        );
      });

      test('does not fall back to the hint when the label is set', () {
        final report = check(flutter(1, box, name: 'E-mail'), native('0', box, label: 'Mail', hint: 'E-mail'));

        expect(report.findings.single.rule, 'name-mismatch');
      });
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

    test('does not fire for a node with no area', () {
      final report = CrossCheck.run(
        [],
        tree([
          native('0', const A11yRect(10, 10, 0, 0), clickable: true),
          native('1', const A11yRect(10, 10, 48, 0), clickable: true),
        ], platform: 'ios'),
      );

      expect(report.findings, isEmpty);
    });

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
            'wcag': '2.5.8',
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
      expect(json['matches'], hasLength(5));
      expect(json['findings'], hasLength(5));
    });

    test('summary prints counts per severity, then one line per finding', () {
      final report = CrossCheck.run(
        [flutter(1, box, name: 'Save')],
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

  group('role-mismatch', () {
    test('fires for a tap node the platform exposes as non-clickable static text', () {
      final report = CrossCheck.run([
        flutter(1, box, role: 'text', name: 'Back', actions: ['tap']),
      ], tree([native('0.0', box, role: 'text', label: 'Back')], platform: 'ios'));

      expect(rules(report), ['role-mismatch']);
      final f = report.findings.single;
      expect(f.severity, 'warning');
      expect(f.source, 'crosscheck');
      expect(f.flutterId, 1);
      expect(f.nativePath, '0.0');
      expect(f.wcag, '4.1.2');
      expect(
        f.message,
        'Flutter text "Back" is a control, but the platform exposes android.view.View "Back" with no control role',
      );
    });

    test('fires for a control role without a tap action, native role other', () {
      final report = CrossCheck.run([
        flutter(1, box, role: 'slider', name: 'Volume'),
      ], tree([native('0.0', box, label: 'Volume')]));
      expect(rules(report), ['role-mismatch']);
    });

    test('does not fire for a clickable native node', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'Back', actions: ['tap']),
      ], tree([native('0.0', box, role: 'button', label: 'Back', clickable: true)]));
      expect(rules(report), isEmpty);
    });

    test('does not fire for a non-interactive Flutter text', () {
      final report = CrossCheck.run([
        flutter(1, box, name: 'Hello'),
      ], tree([native('0.0', box, role: 'text', label: 'Hello')]));
      expect(rules(report), isEmpty);
    });

    test('does not fire for an unmatched node', () {
      final report = CrossCheck.run([
        flutter(1, box, role: 'button', name: 'Back', actions: ['tap']),
      ], tree([native('0.0', far, label: 'Back')]));
      expect(rules(report), ['not-exposed']);
    });

    test('does not fire when the native role is a control role', () {
      final report = CrossCheck.run([
        flutter(1, box, role: 'toggle', name: 'Wi-Fi', actions: ['tap']),
      ], tree([native('0.0', box, role: 'switch', label: 'Wi-Fi')]));
      expect(rules(report), isEmpty);
    });
  });

  group('wcag', () {
    Map<String, String?> wcagByRule(List<NativeIssue> issues) {
      final report = CrossCheck.run([], tree([], issues: issues));
      return {for (final f in report.findings) f.rule: f.wcag};
    }

    NativeIssue issue(String source, String check) =>
        NativeIssue(source: source, check: check, severity: 'warning', message: 'm');

    test('ATF checks map per the spec table, an unknown check has none', () {
      expect(
        wcagByRule([
          issue('atf', 'TouchTargetSizeCheck'),
          issue('atf', 'TextContrastCheck'),
          issue('atf', 'ImageContrastCheck'),
          issue('atf', 'TextSizeCheck'),
          issue('atf', 'TraversalOrderCheck'),
          issue('atf', 'LinkPurposeUnclearCheck'),
          issue('atf', 'DuplicateSpeakableTextCheck'),
          issue('atf', 'SpeakableTextPresentCheck'),
          issue('atf', 'ClassNameCheck'),
          issue('atf', 'OddCheck'),
        ]),
        {
          'TouchTargetSizeCheck': '2.5.8',
          'TextContrastCheck': '1.4.3',
          'ImageContrastCheck': '1.4.11',
          'TextSizeCheck': '1.4.4',
          'TraversalOrderCheck': '1.3.2',
          'LinkPurposeUnclearCheck': '2.4.4',
          'DuplicateSpeakableTextCheck': '2.4.6',
          'SpeakableTextPresentCheck': '4.1.2',
          'ClassNameCheck': '4.1.2',
          'OddCheck': null,
        },
      );
    });

    test('Apple checks map per the spec table', () {
      expect(
        wcagByRule([
          issue('apple', 'contrast'),
          issue('apple', 'hitRegion'),
          issue('apple', 'dynamicType'),
          issue('apple', 'textClipped'),
          issue('apple', 'trait'),
          issue('apple', 'other'),
        ]),
        {
          'contrast': '1.4.3',
          'hitRegion': '2.5.8',
          'dynamicType': '1.4.4',
          'textClipped': '1.4.4',
          'trait': '4.1.2',
          'other': null,
        },
      );
    });

    test('a check name from another source gets no wcag', () {
      expect(wcagByRule([issue('apple', 'TouchTargetSizeCheck')]), {'TouchTargetSizeCheck': null});
    });

    test('cross-check rules carry 4.1.2', () {
      final report = CrossCheck.run(
        [
          flutter(1, box, name: 'Save', actions: ['tap']),
          flutter(2, far, name: 'Lost', actions: ['tap']),
        ],
        tree([
          native('0.0', box, role: 'button', label: 'Submit', clickable: true),
          native('0.1', const A11yRect(0, 300, 10, 10), clickable: true),
        ]),
      );
      expect(rules(report), ['name-mismatch', 'not-exposed', 'native-unnamed']);
      expect({for (final f in report.findings) f.wcag}, {'4.1.2'});
    });

    test('Finding.toJson leaves wcag out when null and writes it when set', () {
      const bare = Finding(rule: 'r', source: 's', severity: 'info', message: 'm');
      expect(bare.toJson().containsKey('wcag'), isFalse);
      expect(
        const Finding(rule: 'r', source: 's', severity: 'info', message: 'm', wcag: '1.4.3').toJson()['wcag'],
        '1.4.3',
      );
    });
  });
}
