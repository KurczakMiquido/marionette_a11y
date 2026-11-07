import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/semantics.dart';

import 'a11y_role.dart';

class A11yNode {
  const A11yNode({
    required this.id,
    required this.role,
    required this.rect,
    this.label = '',
    this.value = '',
    this.hint = '',
    this.tooltip = '',
    this.identifier = '',
    this.isHeader = false,
    this.offscreen = false,
    this.checked,
    this.toggled,
    this.selected,
    this.enabled,
    this.expanded,
    this.actions = const {},
    this.hasNamedDescendants = false,
  });

  factory A11yNode.fromSemantics(SemanticsNode node, Rect globalRect, {bool hasNamedDescendants = false}) {
    final data = node.getSemanticsData();
    final flags = data.flagsCollection;

    return A11yNode(
      id: node.id,
      role: _roleOf(flags),
      rect: globalRect,
      label: data.label,
      value: data.value,
      hint: data.hint,
      tooltip: data.tooltip,
      identifier: data.identifier,
      isHeader: flags.isHeader,
      offscreen: flags.isHidden,
      checked: switch (flags.isChecked) {
        CheckedState.isTrue => true,
        CheckedState.isFalse => false,
        CheckedState.none || CheckedState.mixed => null,
      },
      toggled: flags.isToggled.toBoolOrNull(),
      selected: flags.isSelected.toBoolOrNull(),
      enabled: flags.isEnabled.toBoolOrNull(),
      expanded: flags.isExpanded.toBoolOrNull(),
      actions: {
        for (final action in SemanticsAction.values)
          if (data.hasAction(action)) action,
      },
      hasNamedDescendants: hasNamedDescendants,
    );
  }

  final int id;
  final A11yRole role;
  final Rect rect;
  final String label;
  final String value;
  final String hint;
  final String tooltip;
  final String identifier;
  final bool isHeader;
  final bool offscreen;
  final bool? checked;
  final bool? toggled;
  final bool? selected;
  final bool? enabled;
  final bool? expanded;
  final Set<SemanticsAction> actions;
  final bool hasNamedDescendants;

  // TalkBack skips an unnamed actionable node whose children speak (verified on a real device).
  bool get isSkippedContainer => name.isEmpty && hasNamedDescendants;

  // Screen readers fall back to the tooltip when there is no label.
  String get name => label.isNotEmpty ? label : tooltip;

  bool get isTappable => actions.contains(SemanticsAction.tap) || actions.contains(SemanticsAction.longPress);

  bool get isActionable => isTappable || role != A11yRole.text && role != A11yRole.image;

  bool get hasContent => name.isNotEmpty || value.isNotEmpty || hint.isNotEmpty;

  Map<String, Object?> toJson({bool includeRect = false}) => {
    'id': id,
    'role': role.name,
    if (name.isNotEmpty) 'name': name,
    if (value.isNotEmpty) 'value': value,
    if (hint.isNotEmpty) 'hint': hint,
    if (identifier.isNotEmpty) 'identifier': identifier,
    if (isHeader) 'header': true,
    if (offscreen) 'offscreen': true,
    if (checked != null) 'checked': checked,
    if (toggled != null) 'toggled': toggled,
    if (selected != null) 'selected': selected,
    if (enabled == false) 'enabled': false,
    if (expanded != null) 'expanded': expanded,
    if (actions.isNotEmpty) 'actions': [for (final action in actions) action.name],
    if (includeRect) 'rect': [rect.left, rect.top, rect.width, rect.height].map((v) => v.roundToDouble()).toList(),
  };

  static A11yRole _roleOf(SemanticsFlags flags) {
    if (flags.isTextField) return A11yRole.textField;
    if (flags.isSlider) return A11yRole.slider;
    if (flags.isChecked != CheckedState.none) {
      return flags.isInMutuallyExclusiveGroup ? A11yRole.radio : A11yRole.checkbox;
    }
    if (flags.isToggled != Tristate.none) return A11yRole.toggle;
    if (flags.isLink) return A11yRole.link;
    if (flags.isButton) return A11yRole.button;
    if (flags.isImage) return A11yRole.image;

    return A11yRole.text;
  }
}
