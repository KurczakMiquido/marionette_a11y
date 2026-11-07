import 'a11y_rect.dart';

/// One node of the `ext.flutter.a11y.snapshot` result (called with `includeRects=true`).
class FlutterNode {
  const FlutterNode({
    required this.id,
    required this.role,
    required this.rect,
    this.name = '',
    this.value = '',
    this.hint = '',
    this.identifier = '',
    this.header = false,
    this.offscreen = false,
    this.checked,
    this.toggled,
    this.selected,
    this.enabled,
    this.expanded,
    this.actions = const [],
  });

  factory FlutterNode.fromJson(Map<String, dynamic> json) => FlutterNode(
    id: json['id'] as int,
    role: json['role'] as String,
    rect: A11yRect.fromList(json['rect'] as List),
    name: json['name'] as String? ?? '',
    value: json['value'] as String? ?? '',
    hint: json['hint'] as String? ?? '',
    identifier: json['identifier'] as String? ?? '',
    header: json['header'] as bool? ?? false,
    offscreen: json['offscreen'] as bool? ?? false,
    checked: json['checked'] as bool?,
    toggled: json['toggled'] as bool?,
    selected: json['selected'] as bool?,
    enabled: json['enabled'] as bool?,
    expanded: json['expanded'] as bool?,
    actions: [for (final a in json['actions'] as List? ?? const []) a as String],
  );

  final int id;
  final String role;
  final A11yRect rect;
  final String name;
  final String value;
  final String hint;
  final String identifier;
  final bool header;
  final bool offscreen;
  final bool? checked;
  final bool? toggled;
  final bool? selected;
  final bool? enabled;
  final bool? expanded;
  final List<String> actions;

  /// Optional keys are left out when empty, false or unset, as the in-app snapshot does.
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    if (name.isNotEmpty) 'name': name,
    if (value.isNotEmpty) 'value': value,
    if (hint.isNotEmpty) 'hint': hint,
    if (identifier.isNotEmpty) 'identifier': identifier,
    if (header) 'header': true,
    if (offscreen) 'offscreen': true,
    if (checked != null) 'checked': checked,
    if (toggled != null) 'toggled': toggled,
    if (selected != null) 'selected': selected,
    if (enabled != null) 'enabled': enabled,
    if (expanded != null) 'expanded': expanded,
    if (actions.isNotEmpty) 'actions': actions,
    'rect': rect.toList(),
  };
}
