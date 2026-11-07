import 'package:flutter/material.dart';

/// The same screen with typical accessibility mistakes, or with them fixed.
class BookingScreen extends StatelessWidget {
  const BookingScreen({required this.accessible, super.key});

  final bool accessible;

  @override
  Widget build(BuildContext context) {
    final title = Text('Umów wizytę', style: Theme.of(context).textTheme.headlineSmall);
    void back() => Navigator.pop(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              spacing: 8,
              children: [
                if (accessible)
                  IconButton(tooltip: 'Wróć', onPressed: back, icon: const Icon(Icons.arrow_back))
                else
                  InkWell(onTap: back, child: const Icon(Icons.arrow_back, size: 20)),
                // Without container the header flag lands on the whole row and is read before "Wróć".
                if (accessible) Semantics(header: true, container: true, child: title) else title,
              ],
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'E-mail')),
            for (final test in ['Morfologia', 'Lipidogram'])
              ListTile(
                title: Text(test),
                trailing: accessible
                    ? IconButton(tooltip: 'Usuń: $test', onPressed: () {}, icon: const Icon(Icons.close))
                    : IconButton(
                        tooltip: 'Usuń',
                        onPressed: () {},
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        icon: const Icon(Icons.close),
                      ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: accessible ? 'Wybierz termin' : null,
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month),
                ),
                TextButton(onPressed: () {}, child: Text(accessible ? 'Przeczytaj regulamin' : 'Kliknij tutaj')),
              ],
            ),
            ElevatedButton(
              onPressed: () {},
              child: Text('Zapisz', semanticsLabel: accessible ? null : 'Przycisk zapisz'),
            ),
          ],
        ),
      ),
    );
  }
}
