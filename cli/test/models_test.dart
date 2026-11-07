import 'dart:convert';
import 'dart:io';

import 'package:a11y_cli/a11y_cli.dart';
import 'package:test/test.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  for (final name in ['native_android', 'native_ios']) {
    test('$name round-trips through NativeTree', () {
      final json = fixture(name);
      final tree = NativeTree.fromJson(json);
      expect(tree.nodes, isNotEmpty);
      expect(tree.issues, isNotEmpty);
      expect(jsonDecode(jsonEncode(tree.toJson())), json);
    });
  }

  test('native fixtures parse typed fields', () {
    final tree = NativeTree.fromJson(fixture('native_android'));
    expect(tree.platform, 'android');
    expect(tree.screen.scale, 2.625);
    final field = tree.nodes.singleWhere((n) => n.role == 'textField');
    expect(field.nativeType, 'android.widget.EditText');
    expect(field.label, '');
    expect(field.hint, 'E-mail');
    expect(field.checked, isNull);
    expect(field.heading, isFalse);
    expect(field.rect.width, 379.4);
    expect(tree.issues.first.nodePath, '0.0.0.0.0.0.0.0.5.0');
  });

  test('ios fixture has no checked or heading state', () {
    final tree = NativeTree.fromJson(fixture('native_ios'));
    expect(tree.platform, 'ios');
    expect(tree.screen.scale, 3);
    expect({for (final n in tree.nodes) (n.checked, n.heading)}, {(null, null)});
    expect(tree.nodes.singleWhere((n) => n.role == 'textField').label, 'E-mail');
  });

  test('issue with null nodePath and rect round-trips', () {
    final json = {'source': 'atf', 'check': 'X', 'severity': 'info', 'message': 'm', 'nodePath': null, 'rect': null};
    final issue = NativeIssue.fromJson(json);
    expect(issue.nodePath, isNull);
    expect(issue.rect, isNull);
    expect(issue.toJson(), json);
  });

  test('flutter snapshot nodes round-trip and omit empty keys', () {
    final json = fixture('flutter_snapshot');
    final nodes = (json['nodes'] as List).cast<Map<String, dynamic>>();
    for (final raw in nodes) {
      expect(FlutterNode.fromJson(raw).toJson(), raw);
    }
    final minimal = FlutterNode.fromJson({
      'id': 9,
      'role': 'text',
      'rect': [0, 0, 1, 1],
    });
    expect(minimal.name, '');
    expect(minimal.header, isFalse);
    expect(minimal.actions, isEmpty);
    expect(minimal.checked, isNull);
    expect(minimal.toJson().keys, unorderedEquals(['id', 'role', 'rect']));
  });

  group('A11yRect.iou', () {
    test('identical rects give 1', () {
      const r = A11yRect(0, 0, 10, 10);
      expect(r.iou(r), 1.0);
    });
    test('disjoint rects give 0', () {
      expect(const A11yRect(0, 0, 10, 10).iou(const A11yRect(20, 20, 5, 5)), 0.0);
    });
    test('half overlap gives 1/3', () {
      expect(const A11yRect(0, 0, 10, 10).iou(const A11yRect(5, 0, 10, 10)), closeTo(1 / 3, 1e-9));
    });
    test('fromList and toList', () {
      expect(A11yRect.fromList([1, 2.5, 3, 4]).toList(), [1.0, 2.5, 3.0, 4.0]);
    });
  });

  test('wrong schema throws FormatException', () {
    final json = fixture('native_android')..['schema'] = 'a11y-native/v2';
    expect(() => NativeTree.fromJson(json), throwsFormatException);
  });
}
