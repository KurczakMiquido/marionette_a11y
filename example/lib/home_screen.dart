import 'package:flutter/material.dart';

import 'booking_screen.dart';
import 'controls_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(bool accessible) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => BookingScreen(accessible: accessible)));

    return Scaffold(
      appBar: AppBar(title: const Text('marionette_a11y')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            ElevatedButton(onPressed: () => open(false), child: const Text('Wersja z błędami')),
            ElevatedButton(onPressed: () => open(true), child: const Text('Wersja poprawiona')),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ControlsScreen())),
              child: const Text('Kontrolki'),
            ),
          ],
        ),
      ),
    );
  }
}
