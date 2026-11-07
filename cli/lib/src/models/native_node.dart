import 'a11y_rect.dart';

/// One node of the native accessibility tree (`a11y-native/v1`).
class NativeNode {
  const NativeNode({
    required this.path,
    required this.nativeType,
    required this.role,
    required this.label,
    required this.value,
    required this.hint,
    required this.identifier,
    required this.rect,
    required this.focusable,
    required this.clickable,
    required this.enabled,
    required this.selected,
    required this.checked,
    required this.heading,
  });

  factory NativeNode.fromJson(Map<String, dynamic> json) => NativeNode(
        path: json['path'] as String,
        nativeType: json['nativeType'] as String,
        role: json['role'] as String,
        label: json['label'] as String,
        value: json['value'] as String,
        hint: json['hint'] as String,
        identifier: json['identifier'] as String,
        rect: A11yRect.fromList(json['rect'] as List),
        focusable: json['focusable'] as bool,
        clickable: json['clickable'] as bool,
        enabled: json['enabled'] as bool,
        selected: json['selected'] as bool,
        checked: json['checked'] as bool?,
        heading: json['heading'] as bool?,
      );

  final String path;
  final String nativeType;
  final String role;
  final String label;
  final String value;
  final String hint;
  final String identifier;
  final A11yRect rect;
  final bool focusable;
  final bool clickable;
  final bool enabled;
  final bool selected;
  final bool? checked;
  final bool? heading;

  Map<String, dynamic> toJson() => {
        'path': path,
        'nativeType': nativeType,
        'role': role,
        'label': label,
        'value': value,
        'hint': hint,
        'identifier': identifier,
        'rect': rect.toList(),
        'focusable': focusable,
        'clickable': clickable,
        'enabled': enabled,
        'selected': selected,
        'checked': checked,
        'heading': heading,
      };
}
