import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_a11y/marionette_a11y.dart';
import 'package:marionette_a11y_example/controls_screen.dart';

void main() {
  testWidgets('slider and progress bar carry a name and a value; the button opens a dialog', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: ControlsScreen()));

    expect(
      [
        for (final node in A11ySnapshot.capture().nodes)
          if (node.value.isNotEmpty) (node.role, node.name, node.value),
      ],
      [(A11yRole.slider, 'Głośność', '50%'), (A11yRole.text, 'Postęp pobierania', '40')],
    );

    await tester.tap(find.text('Pokaż okno'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the save button is one node with a label and a tooltip', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: ControlsScreen()));

    expect(
      [
        for (final node in A11ySnapshot.capture().nodes)
          if (node.tooltip.isNotEmpty) (node.role, node.label, node.tooltip),
      ],
      [(A11yRole.button, 'Zapisz', 'Zapisuje ustawienia')],
    );
    handle.dispose();
  });
}
