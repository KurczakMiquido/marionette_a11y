import 'a11y_node.dart';

const _vocabulary = {
  'pl': {
    'button': 'Przycisk',
    'textField': 'Pole edycji',
    'checkbox': 'Pole wyboru',
    'radio': 'Przycisk opcji',
    'toggle': 'Przełącznik',
    'slider': 'Suwak',
    'link': 'Link',
    'image': 'Obraz',
    'header': 'Nagłówek',
    'checked': 'Zaznaczone',
    'unchecked': 'Niezaznaczone',
    'on': 'Włączone',
    'off': 'Wyłączone',
    'selected': 'Wybrane',
    'disabled': 'Nieaktywne',
    'expanded': 'Rozwinięte',
    'collapsed': 'Zwinięte',
  },
  'en': {
    'button': 'Button',
    'textField': 'Edit box',
    'checkbox': 'Checkbox',
    'radio': 'Radio button',
    'toggle': 'Switch',
    'slider': 'Slider',
    'link': 'Link',
    'image': 'Image',
    'header': 'Heading',
    'checked': 'Checked',
    'unchecked': 'Not checked',
    'on': 'On',
    'off': 'Off',
    'selected': 'Selected',
    'disabled': 'Disabled',
    'expanded': 'Expanded',
    'collapsed': 'Collapsed',
  },
};

/// Approximates TalkBack's phrasing; calibrate against a real TalkBack speech log.
class ScreenReaderAnnouncer {
  const ScreenReaderAnnouncer({this.locale = 'pl'});

  final String locale;

  String announce(A11yNode node) {
    final words = _vocabulary[locale] ?? _vocabulary['en']!;
    final checked = node.checked;
    final toggled = node.toggled;
    final expanded = node.expanded;

    return [
      node.name,
      node.value,
      words[node.role.name] ?? '',
      if (node.isHeader) words['header']!,
      if (checked != null) words[checked ? 'checked' : 'unchecked']!,
      if (toggled != null) words[toggled ? 'on' : 'off']!,
      if (node.selected ?? false) words['selected']!,
      if (node.enabled == false) words['disabled']!,
      if (expanded != null) words[expanded ? 'expanded' : 'collapsed']!,
      node.hint,
    ].where((part) => part.isNotEmpty).join(', ');
  }
}
