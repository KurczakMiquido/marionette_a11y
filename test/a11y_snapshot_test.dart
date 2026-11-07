import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_a11y/marionette_a11y.dart';

Future<A11ySnapshot> _capture(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
  return A11ySnapshot.capture();
}

void main() {
  testWidgets('transcript follows swipe order and names roles in Polish', (tester) async {
    final handle = tester.ensureSemantics();
    final snapshot = await _capture(
      tester,
      Column(
        children: [
          Semantics(header: true, child: const Text('Umów wizytę')),
          const Text('Wybierz badania'),
          Checkbox(value: true, onChanged: (_) {}),
          ElevatedButton(onPressed: () {}, child: const Text('Zapisz')),
        ],
      ),
    );

    expect(snapshot.transcript(), [
      'Umów wizytę, Nagłówek',
      'Wybierz badania',
      'Pole wyboru, Zaznaczone',
      'Zapisz, Przycisk',
    ]);
    handle.dispose();
  });

  testWidgets('switch announces its state in English', (tester) async {
    final handle = tester.ensureSemantics();
    final snapshot = await _capture(
      tester,
      SwitchListTile(title: const Text('Notifications'), value: false, onChanged: (_) {}),
    );

    expect(snapshot.transcript(locale: 'en'), ['Notifications, Switch, Off']);
    handle.dispose();
  });

  testWidgets('rects are global and in logical pixels', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final snapshot = await _capture(
      tester,
      Padding(
        padding: const EdgeInsets.only(left: 30, top: 40),
        child: Align(
          alignment: Alignment.topLeft,
          child: Semantics(
            container: true,
            button: true,
            label: 'Usuń',
            onTap: () {},
            child: const SizedBox(width: 100, height: 50),
          ),
        ),
      ),
    );

    final node = snapshot.nodes.singleWhere((node) => node.name == 'Usuń');
    expect(node.rect, const Rect.fromLTWH(30, 40, 100, 50));
    handle.dispose();
  });
}
