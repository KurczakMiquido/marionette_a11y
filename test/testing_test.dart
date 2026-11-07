import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_a11y/marionette_a11y.dart';
import 'package:marionette_a11y/testing.dart';

Widget _app(Widget body) => MaterialApp(
  home: Scaffold(body: Center(child: body)),
);

void main() {
  late SemanticsHandle handle;
  late bool savedAutoUpdate;
  late GoldenFileComparator savedComparator;
  late Directory tmp;

  setUp(() {
    savedAutoUpdate = autoUpdateGoldenFiles;
    savedComparator = goldenFileComparator;
    tmp = Directory.systemTemp.createTempSync('a11y_golden_');
  });

  tearDown(() {
    autoUpdateGoldenFiles = savedAutoUpdate;
    goldenFileComparator = savedComparator;
    tmp.deleteSync(recursive: true);
  });

  group('A11yAuditGuideline', () {
    testWidgets('passes a clean screen', (tester) async {
      handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ElevatedButton(onPressed: () {}, child: const Text('Zapisz'))));

      await expectLater(tester, meetsGuideline(const A11yAuditGuideline()));
      handle.dispose();
    });

    testWidgets('fails an unnamed button with one line per finding', (tester) async {
      handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(IconButton(onPressed: () {}, icon: const Icon(Icons.delete))));

      final result = await const A11yAuditGuideline().evaluate(tester);

      expect(result.passed, isFalse);
      expect(
        result.reason,
        matches(RegExp(r'\[error\] missing-name \(WCAG [^)]+\) — .+ — "" at \[\d+, \d+, \d+, \d+\]')),
      );
      handle.dispose();
    });

    testWidgets('failOn warning fails a warning-only screen; the default does not', (tester) async {
      handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ElevatedButton(onPressed: () {}, child: const Text('Kliknij tutaj'))));
      final findings = A11yAudit.run(A11ySnapshot.capture());
      expect(findings.map((finding) => finding.severity).toSet(), {A11ySeverity.warning});

      expect((await const A11yAuditGuideline().evaluate(tester)).passed, isTrue);
      final strict = await const A11yAuditGuideline(failOn: A11ySeverity.warning).evaluate(tester);
      expect(strict.passed, isFalse);
      expect(strict.reason, contains('[warning] generic-name'));
      handle.dispose();
    });

    testWidgets('fails an empty snapshot with a hint', (tester) async {
      await tester.pumpWidget(_app(const SizedBox()));

      final result = await const A11yAuditGuideline().evaluate(tester);

      expect(result.passed, isFalse);
      expect(result.reason, 'no semantics nodes; call tester.ensureSemantics() first');
    });
  });

  group('matchesA11yTranscript', () {
    Future<void> pumpButton(WidgetTester tester) =>
        tester.pumpWidget(_app(ElevatedButton(onPressed: () {}, child: const Text('Zapisz'))));

    testWidgets('passes when the golden equals the transcript', (tester) async {
      handle = tester.ensureSemantics();
      await pumpButton(tester);
      final file = File('${tmp.path}/ok.txt')..writeAsStringSync('Zapisz, Przycisk\n');
      goldenFileComparator = LocalFileComparator(Uri.file('${tmp.path}/test.dart'));

      await expectLater(tester, matchesA11yTranscript(file.path));
      handle.dispose();
    });

    testWidgets('fails with a line diff', (tester) async {
      handle = tester.ensureSemantics();
      await pumpButton(tester);
      final file = File('${tmp.path}/diff.txt')..writeAsStringSync('Zapisz, Link\n');

      final matcher = matchesA11yTranscript(file.path);
      final problem = await matcher.matchAsync(tester);

      expect(problem, contains('-Zapisz, Link'));
      expect(problem, contains('+Zapisz, Przycisk'));
      handle.dispose();
    });

    testWidgets('fails on a missing file', (tester) async {
      handle = tester.ensureSemantics();
      await pumpButton(tester);
      final path = '${tmp.path}/none.txt';

      final problem = await matchesA11yTranscript(path).matchAsync(tester);

      expect(problem, 'golden $path not found; run flutter test --update-goldens');
      handle.dispose();
    });

    testWidgets('writes the file when autoUpdateGoldenFiles is true', (tester) async {
      handle = tester.ensureSemantics();
      await pumpButton(tester);
      final file = File('${tmp.path}/nested/dir/new.txt');
      autoUpdateGoldenFiles = true;

      await expectLater(tester, matchesA11yTranscript(file.path));
      // The binding asserts the flag is unset before tearDown runs.
      autoUpdateGoldenFiles = savedAutoUpdate;

      expect(file.readAsStringSync(), 'Zapisz, Przycisk\n');
      handle.dispose();
    });

    testWidgets('resolves a relative path against LocalFileComparator.basedir', (tester) async {
      handle = tester.ensureSemantics();
      await pumpButton(tester);
      File('${tmp.path}/goldens/rel.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('Zapisz, Przycisk\n');
      goldenFileComparator = LocalFileComparator(Uri.file('${tmp.path}/some_test.dart'));

      await expectLater(tester, matchesA11yTranscript('goldens/rel.txt'));
      handle.dispose();
    });
  });
}
