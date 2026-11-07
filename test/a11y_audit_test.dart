import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_a11y/marionette_a11y.dart';

final _heading = Semantics(header: true, child: const Text('Umów wizytę'));

Future<List<A11yFinding>> _audit(WidgetTester tester, List<Widget> children) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Column(children: children)),
    ),
  );
  return A11yAudit.run(A11ySnapshot.capture());
}

Iterable<String> _rules(List<A11yFinding> findings) => findings.map((finding) => finding.rule);

void main() {
  testWidgets('a clean screen has no findings', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      _heading,
      const TextField(decoration: InputDecoration(labelText: 'E-mail')),
      IconButton(tooltip: 'Usuń morfologię', onPressed: () {}, icon: const Icon(Icons.delete)),
      ElevatedButton(onPressed: () {}, child: const Text('Zapisz')),
    ]);

    expect(findings, isEmpty);
    handle.dispose();
  });

  testWidgets('icon button without a name fails 4.1.2', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [_heading, IconButton(onPressed: () {}, icon: const Icon(Icons.delete))]);

    final finding = findings.single;
    expect(finding.rule, 'missing-name');
    expect(finding.wcag, '4.1.2');
    expect(finding.severity, A11ySeverity.error);
    handle.dispose();
  });

  testWidgets('tappable text without a button role is flagged under 4.1.2', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      _heading,
      Semantics(container: true, label: 'Wróć', onTap: () {}, child: const SizedBox.square(dimension: 48)),
    ]);

    expect(_rules(findings), ['missing-role']);
    handle.dispose();
  });

  testWidgets('target under 24x24 fails 2.5.8, under 48x48 warns', (tester) async {
    final handle = tester.ensureSemantics();
    Widget target(String label, double size) => Semantics(
      container: true,
      button: true,
      label: label,
      onTap: () {},
      child: SizedBox.square(dimension: size),
    );
    final findings = await _audit(tester, [_heading, target('Usuń', 20), target('Edytuj', 40)]);

    expect(findings.map((finding) => (finding.rule, finding.node?.name, finding.severity)), [
      ('target-size', 'Usuń', A11ySeverity.error),
      ('target-size-platform', 'Edytuj', A11ySeverity.warning),
    ]);
    handle.dispose();
  });

  testWidgets('asset-like and generic names are flagged', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      _heading,
      IconButton(tooltip: 'ic_delete', onPressed: () {}, icon: const Icon(Icons.delete)),
      IconButton(tooltip: 'Ikona', onPressed: () {}, icon: const Icon(Icons.edit)),
    ]);

    expect(_rules(findings), ['generic-name', 'generic-name']);
    handle.dispose();
  });

  testWidgets('role repeated in the name is flagged', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      _heading,
      ElevatedButton(
        onPressed: () {},
        child: const Text('Zapisz', semanticsLabel: 'Przycisk zapisz'),
      ),
    ]);

    expect(_rules(findings), ['role-in-name']);
    handle.dispose();
  });

  testWidgets('buttons sharing a name are reported once', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      _heading,
      TextButton(onPressed: () {}, child: const Text('Usuń')),
      TextButton(onPressed: () {}, child: const Text('Usuń')),
    ]);

    expect(_rules(findings), ['duplicate-name']);
    handle.dispose();
  });

  testWidgets('screen without a heading is flagged under 1.3.1', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = await _audit(tester, [
      const Text('Umów wizytę'),
      ElevatedButton(onPressed: () {}, child: const Text('Zapisz')),
    ]);

    expect(findings.single.rule, 'no-heading');
    expect(findings.single.node, isNull);
    handle.dispose();
  });
}
