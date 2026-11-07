import 'models/a11y_rect.dart';
import 'models/check_report.dart';
import 'models/finding.dart';
import 'models/flutter_node.dart';
import 'models/native_node.dart';
import 'models/native_tree.dart';
import 'models/node_match.dart';
import 'wcag_reference.dart';

/// Joins the Flutter semantics snapshot with the native tree and reports where they disagree.
class CrossCheck {
  static const iouThreshold = 0.6;
  static const _source = 'crosscheck';
  static const _sameIou = 1e-9;
  static const _controlRoles = {'button', 'link', 'textField', 'checkbox', 'radio', 'toggle', 'slider'};
  static const _plainRoles = {'text', 'other', 'image'};

  static CheckReport run(List<FlutterNode> flutterNodes, NativeTree native) {
    final onScreen = [
      for (final f in flutterNodes)
        if (!f.offscreen) f,
    ];
    final matched = _match(onScreen, native.nodes);
    final flutterIdByPath = {
      for (final (i, m) in matched.indexed)
        if (m != null) m.node.path: onScreen[i].id,
    };

    final findings = <Finding>[];
    for (final (i, f) in onScreen.indexed) {
      final n = matched[i]?.node;
      if (n == null) {
        if (_hasContent(f) || f.actions.contains('tap')) {
          findings.add(
            Finding(
              rule: 'not-exposed',
              source: _source,
              severity: 'error',
              message: 'Flutter node ${f.id} ${_describe(f)} at ${_format(f.rect)} has no native counterpart',
              flutterId: f.id,
              rect: f.rect,
              wcag: WcagReference.crosscheck,
            ),
          );
        }
        continue;
      }
      final mismatch = native.platform == 'android' ? _androidNameMismatch(f, n) : _nameMismatch(f, n);
      if (mismatch != null) {
        findings.add(
          Finding(
            rule: 'name-mismatch',
            source: _source,
            severity: 'warning',
            message: mismatch,
            flutterId: f.id,
            nativePath: n.path,
            rect: f.rect,
            wcag: WcagReference.crosscheck,
          ),
        );
      }
      if (_isControl(f) && !n.clickable && _plainRoles.contains(n.role)) {
        findings.add(
          Finding(
            rule: 'role-mismatch',
            source: _source,
            severity: 'warning',
            message:
                'Flutter ${f.role} "${f.name}" is a control, but the platform exposes ${n.nativeType} "${n.label}" '
                'with no control role',
            flutterId: f.id,
            nativePath: n.path,
            rect: f.rect,
            wcag: WcagReference.crosscheck,
          ),
        );
      }
    }

    for (final n in native.nodes) {
      if (!n.clickable || n.label.isNotEmpty || n.value.isNotEmpty || n.hint.isNotEmpty) continue;
      // iOS lists hidden Flutter nodes with a zero frame; nobody can reach them.
      if (n.rect.isEmpty) continue;
      final prefix = '${n.path}.';
      if (native.nodes.any((d) => d.path.startsWith(prefix) && d.label.isNotEmpty)) continue;
      findings.add(
        Finding(
          rule: 'native-unnamed',
          source: _source,
          severity: 'error',
          message: 'Clickable ${n.nativeType} at ${_format(n.rect)} has no label, value or hint',
          flutterId: flutterIdByPath[n.path],
          nativePath: n.path,
          rect: n.rect,
          wcag: WcagReference.crosscheck,
        ),
      );
    }

    for (final issue in native.issues) {
      final path = issue.nodePath;
      findings.add(
        Finding(
          rule: issue.check,
          source: issue.source,
          severity: issue.severity,
          message: issue.message,
          flutterId: path == null ? null : flutterIdByPath[path],
          nativePath: path,
          rect: issue.rect,
          wcag: WcagReference.forNative(issue.source, issue.check),
        ),
      );
    }

    return CheckReport(
      flutterNodes: flutterNodes,
      native: native,
      matches: [
        for (final (i, m) in matched.indexed)
          if (m != null) NodeMatch(flutterId: onScreen[i].id, nativePath: m.node.path, by: m.by),
      ],
      findings: findings,
    );
  }

  /// Flutter's iOS bridge joins label and tooltip with a newline into the accessibility label. That is compared with
  /// the native label, or with the native hint when the label is empty, as iOS keeps label, value and hint apart.
  /// Returns the finding's message, or null when they agree.
  static String? _nameMismatch(FlutterNode f, NativeNode n) {
    final (field, nativeName) = n.label.isNotEmpty || n.hint.isEmpty ? ('label', n.label) : ('hint', n.hint);
    final parts = [
      for (final (what, text) in [('name', f.label), ('tooltip', f.tooltip)])
        if (text.isNotEmpty) (what, text),
    ];
    final composed = parts.map((p) => p.$2).join('\n');
    if (normalize(composed) == normalize(nativeName)) return null;
    return 'Flutter ${_parts(parts)} "$composed" differs from native $field "$nativeName"';
  }

  /// Flutter's Android bridge joins value, label and hint with ", " into the content description (the tooltip when
  /// all three are empty), a text field's label and hint into its hint text, and gives a route scope neither.
  /// Returns the finding's message, or null when the native node says what the bridge composes.
  static String? _androidNameMismatch(FlutterNode f, NativeNode n) {
    if (!n.focusable && n.label.isEmpty && n.hint.isEmpty) return null;
    final textField = f.role == 'textField';
    var parts = [
      for (final (what, text) in [if (!textField) ('value', f.value), ('name', f.label), ('hint', f.hint)])
        if (text.isNotEmpty) (what, text),
    ];
    if (parts.isEmpty && !textField && f.tooltip.isNotEmpty) parts = [('tooltip', f.tooltip)];
    final composed = parts.map((p) => p.$2).join(', ');
    final (field, nativeText) = textField ? ('hint', n.hint) : ('label', n.label);
    if (normalize(composed) == normalize(nativeText)) return null;
    return 'Flutter ${_parts(parts)} "$composed" differs from native $field "$nativeText"';
  }

  static String _parts(List<(String, String)> parts) => parts.isEmpty ? 'name' : parts.map((p) => p.$1).join(' + ');

  /// Lowercase, collapse whitespace runs to one space, strip a trailing run of whitespace and `.,;:`, trim.
  static String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').replaceFirst(RegExp(r'[\s.,;:]+$'), '').trim();

  /// The native match of each Flutter node, by index. Identifier matches go first for every node, so a rect
  /// match cannot take a native node that another Flutter node names by identifier.
  static List<({NativeNode node, String by})?> _match(List<FlutterNode> flutter, List<NativeNode> native) {
    final result = List<({NativeNode node, String by})?>.filled(flutter.length, null);
    final taken = List.filled(native.length, false);

    void take(int i, String by, bool Function(NativeNode) candidate, double minIou) {
      final f = flutter[i];
      int? best;
      var bestIou = -1.0;
      for (final (j, n) in native.indexed) {
        if (taken[j] || !candidate(n)) continue;
        final iou = f.rect.iou(n.rect);
        if (iou < minIou) continue;
        if (best == null || iou > bestIou + _sameIou || (iou > bestIou - _sameIou && _preferred(f, n, native[best]))) {
          best = j;
          bestIou = iou;
        }
      }
      if (best == null) return;
      taken[best] = true;
      result[i] = (node: native[best], by: by);
    }

    for (final (i, f) in flutter.indexed) {
      if (f.identifier.isNotEmpty) take(i, NodeMatch.byIdentifier, (n) => n.identifier == f.identifier, 0);
    }
    for (var i = 0; i < flutter.length; i++) {
      if (result[i] == null) take(i, NodeMatch.byRect, (_) => true, iouThreshold);
    }
    return result;
  }

  /// Tie-break between two native nodes with the same IoU: compatible role first, then the deeper node.
  static bool _preferred(FlutterNode f, NativeNode candidate, NativeNode best) {
    final compatible = _compatible(f, candidate);
    if (compatible != _compatible(f, best)) return compatible;
    return _depth(candidate) > _depth(best);
  }

  static bool _compatible(FlutterNode f, NativeNode n) =>
      f.role == n.role ||
      switch (n.role) {
        'switch' => f.role == 'toggle',
        'header' => f.header,
        // Android reports any clickable view without a better class as a button.
        'button' => f.actions.contains('tap'),
        _ => false,
      };

  static int _depth(NativeNode n) => '.'.allMatches(n.path).length;

  static bool _isControl(FlutterNode f) => f.actions.contains('tap') || _controlRoles.contains(f.role);

  static bool _hasContent(FlutterNode f) => f.name.isNotEmpty || f.value.isNotEmpty || f.hint.isNotEmpty;

  static String _describe(FlutterNode f) {
    if (f.name.isNotEmpty) return '"${f.name}" (${f.role})';
    if (f.value.isNotEmpty) return 'value "${f.value}" (${f.role})';
    if (f.hint.isNotEmpty) return 'hint "${f.hint}" (${f.role})';
    return '(${f.role})';
  }

  static String _format(A11yRect r) => '[${[r.left, r.top, r.width, r.height].map(_number).join(', ')}]';

  static String _number(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
