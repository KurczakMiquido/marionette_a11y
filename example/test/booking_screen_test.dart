import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_a11y/marionette_a11y.dart';
import 'package:marionette_a11y_example/booking_screen.dart';

Future<A11ySnapshot> _capture(WidgetTester tester, {required bool accessible}) async {
  await tester.pumpWidget(MaterialApp(home: BookingScreen(accessible: accessible)));
  return A11ySnapshot.capture();
}

void main() {
  testWidgets('broken version trips every rule', (tester) async {
    final handle = tester.ensureSemantics();
    final findings = A11yAudit.run(await _capture(tester, accessible: false));

    expect(findings.map((finding) => (finding.rule, finding.node?.name)), [
      ('missing-role', 'Umów wizytę'),
      ('target-size-platform', 'Umów wizytę'),
      ('target-size', 'Usuń'),
      ('target-size', 'Usuń'),
      ('missing-name', ''),
      ('generic-name', 'Kliknij tutaj'),
      ('role-in-name', 'Przycisk zapisz'),
      ('duplicate-name', 'Usuń'),
      ('no-heading', null),
    ]);
    handle.dispose();
  });

  testWidgets('fixed version is clean and reads well', (tester) async {
    final handle = tester.ensureSemantics();
    final snapshot = await _capture(tester, accessible: true);

    expect(A11yAudit.run(snapshot), isEmpty);
    expect(snapshot.transcript(), [
      'Wróć, Przycisk',
      'Umów wizytę, Nagłówek',
      'E-mail, Pole edycji',
      'Morfologia',
      'Usuń: Morfologia, Przycisk',
      'Lipidogram',
      'Usuń: Lipidogram, Przycisk',
      'Wybierz termin, Przycisk',
      'Przeczytaj regulamin, Przycisk',
      'Zapisz, Przycisk',
    ]);
    handle.dispose();
  });
}
