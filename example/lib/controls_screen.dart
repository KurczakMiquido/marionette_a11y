import 'package:flutter/material.dart';

/// Controls whose name reaches TalkBack joined with their value, and a dialog whose route scope has no label there.
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  double _volume = 0.5;

  void _showDialog() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Zapisać ustawienia?'),
      content: const Text('Głośność zostanie zapamiętana.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrolki')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Slider uses its label as the semantics label too.
          Slider(value: _volume, label: 'Głośność', onChanged: (value) => setState(() => _volume = value)),
          const SizedBox(height: 24),
          const LinearProgressIndicator(value: 0.4, semanticsLabel: 'Postęp pobierania'),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _showDialog, child: const Text('Pokaż okno')),
        ],
      ),
    );
  }
}
