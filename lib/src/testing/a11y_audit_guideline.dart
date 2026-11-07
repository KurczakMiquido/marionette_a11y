import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../a11y_audit.dart';
import '../a11y_finding.dart';
import '../a11y_severity.dart';
import '../a11y_snapshot.dart';

/// Fails when the live semantics tree has findings at or above [failOn].
///
/// Usage: `await expectLater(tester, meetsGuideline(const A11yAuditGuideline()));`
class A11yAuditGuideline extends AccessibilityGuideline {
  const A11yAuditGuideline({this.failOn = A11ySeverity.error});

  final A11ySeverity failOn;

  @override
  String get description => 'meets the marionette_a11y audit (fails on ${failOn.name})';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final snapshot = A11ySnapshot.capture();
    if (snapshot.nodes.isEmpty) {
      return const Evaluation.fail('no semantics nodes; call tester.ensureSemantics() first');
    }
    // The enum is ordered by severity, most severe first.
    final failing = A11yAudit.run(snapshot).where((finding) => finding.severity.index <= failOn.index);
    if (failing.isEmpty) return const Evaluation.pass();
    return Evaluation.fail(failing.map(_line).join('\n'));
  }

  static String _line(A11yFinding finding) {
    final buffer = StringBuffer(
      '[${finding.severity.name}] ${finding.rule} (WCAG ${finding.wcag}) — ${finding.message}',
    );
    if (finding.node case final node?) {
      final rect = node.rect;
      buffer.write(
        ' — "${node.name}" at [${rect.left.round()}, ${rect.top.round()}, ${rect.width.round()}, ${rect.height.round()}]',
      );
    }
    return buffer.toString();
  }
}
