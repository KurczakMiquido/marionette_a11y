import 'a11y_node.dart';
import 'a11y_severity.dart';

class A11yFinding {
  const A11yFinding({required this.rule, required this.wcag, required this.severity, required this.message, this.node});

  final String rule;
  final String wcag;
  final A11ySeverity severity;
  final String message;

  /// Null for screen-level findings.
  final A11yNode? node;

  Map<String, Object?> toJson() => {
    'rule': rule,
    'wcag': wcag,
    'severity': severity.name,
    'message': message,
    if (node case final node?) 'node': node.toJson(includeRect: true),
  };
}
