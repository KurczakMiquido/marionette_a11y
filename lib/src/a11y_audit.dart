import 'package:collection/collection.dart';

import 'a11y_finding.dart';
import 'a11y_node.dart';
import 'a11y_role.dart';
import 'a11y_severity.dart';
import 'a11y_snapshot.dart';

const _genericNames = {
  'button',
  'przycisk',
  'icon',
  'ikona',
  'image',
  'obraz',
  'obrazek',
  'click',
  'kliknij',
  'tap',
  'here',
  'tutaj',
  'click here',
  'kliknij tutaj',
};
final _assetLikeName = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)+$|\.(png|svg|webp|jpe?g)$');
final _roleWords = RegExp('przycisk|button', caseSensitive: false);
final _usageHint = RegExp('dwukrotnie|double.tap', caseSensitive: false);

/// Checks what the semantics tree can prove. Covers a fraction of WCAG 2.2, not conformance.
abstract final class A11yAudit {
  static List<A11yFinding> run(A11ySnapshot snapshot) {
    final onscreen = snapshot.nodes.where((node) => !node.offscreen).toList();

    return [
      for (final node in snapshot.nodes) ...[
        ?_missingName(node),
        ?_missingRole(node),
        if (!node.offscreen) ?_targetSize(node),
        ?_genericName(node),
        ?_roleInName(node),
        ?_nameRepeated(node),
        ?_usageHintInName(node),
      ],
      ..._duplicateNames(onscreen),
      if (onscreen.isNotEmpty && !onscreen.any((node) => node.isHeader))
        const A11yFinding(
          rule: 'no-heading',
          wcag: '1.3.1',
          severity: A11ySeverity.warning,
          message: 'Screen has no heading; screen reader users cannot jump to its sections.',
        ),
    ];
  }

  static A11yFinding? _missingName(A11yNode node) {
    if (!node.isActionable || node.name.isNotEmpty || node.isSkippedContainer) return null;

    return A11yFinding(
      rule: 'missing-name',
      wcag: '4.1.2',
      severity: A11ySeverity.error,
      node: node,
      message: 'Actionable element has no name; a screen reader announces only its role.',
    );
  }

  // A bare InkWell or GestureDetector merges its tap into the nearest text and never says "button".
  static A11yFinding? _missingRole(A11yNode node) {
    if (!node.isTappable || node.isSkippedContainer || node.role != A11yRole.text && node.role != A11yRole.image) {
      return null;
    }

    return A11yFinding(
      rule: 'missing-role',
      wcag: '4.1.2',
      severity: A11ySeverity.warning,
      node: node,
      message: '"${node.name}" reacts to taps but is announced as plain ${node.role.name}. Use a button widget.',
    );
  }

  static A11yFinding? _targetSize(A11yNode node) {
    if (!node.isTappable) return null;
    final side = node.rect.shortestSide;
    if (side < 24) {
      return A11yFinding(
        rule: 'target-size',
        wcag: '2.5.8',
        severity: A11ySeverity.error,
        node: node,
        message: 'Target is ${side.round()} px on its short side; WCAG 2.2 AA needs 24 unless spacing compensates.',
      );
    }
    if (side < 48) {
      return A11yFinding(
        rule: 'target-size-platform',
        wcag: '2.5.8',
        severity: A11ySeverity.warning,
        node: node,
        message: 'Target is ${side.round()} px; Android asks for 48 dp, iOS for 44 pt.',
      );
    }

    return null;
  }

  static A11yFinding? _genericName(A11yNode node) {
    final name = node.name.trim().toLowerCase();
    if (name.isEmpty || !_genericNames.contains(name) && !_assetLikeName.hasMatch(name)) return null;

    return A11yFinding(
      rule: 'generic-name',
      wcag: '2.4.6',
      severity: A11ySeverity.warning,
      node: node,
      message: 'Name "${node.name}" says nothing about the purpose.',
    );
  }

  static A11yFinding? _roleInName(A11yNode node) {
    if (node.role != A11yRole.button || !_roleWords.hasMatch(node.name)) return null;

    return A11yFinding(
      rule: 'role-in-name',
      wcag: '4.1.2',
      severity: A11ySeverity.warning,
      node: node,
      message: 'Name repeats the role the screen reader already announces: "${node.name}, Przycisk".',
    );
  }

  static A11yFinding? _nameRepeated(A11yNode node) {
    if (node.name.isEmpty || node.value.trim().toLowerCase() != node.name.trim().toLowerCase()) return null;

    return A11yFinding(
      rule: 'name-repeated',
      wcag: '4.1.2',
      severity: A11ySeverity.warning,
      node: node,
      message: 'Value repeats the name, so it is read twice: "${node.name}, ${node.value}". Drop the value.',
    );
  }

  static A11yFinding? _usageHintInName(A11yNode node) {
    if (!_usageHint.hasMatch(node.name)) return null;

    return A11yFinding(
      rule: 'usage-hint-in-name',
      wcag: '4.1.2',
      severity: A11ySeverity.warning,
      node: node,
      message: 'Name carries a usage instruction the screen reader adds itself, so users hear it twice.',
    );
  }

  static Iterable<A11yFinding> _duplicateNames(List<A11yNode> nodes) {
    final groups = nodes
        .where((node) => node.isActionable && node.name.isNotEmpty)
        .groupListsBy((node) => node.name.trim().toLowerCase());

    return [
      for (final group in groups.values)
        if (group.length > 1)
          A11yFinding(
            rule: 'duplicate-name',
            wcag: '2.4.6',
            severity: A11ySeverity.warning,
            node: group.first,
            message:
                '${group.length} controls are named "${group.first.name}"; a screen reader user cannot tell them apart.',
          ),
    ];
  }
}
