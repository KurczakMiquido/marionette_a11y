import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'a11y_audit.dart';
import 'a11y_severity.dart';
import 'a11y_snapshot.dart';

SemanticsHandle? _semanticsHandle;

/// Registers `a11y.snapshot` and `a11y.audit` as marionette MCP tools. Call after the binding exists.
void registerA11yExtensions() {
  // Flutter builds no semantics tree until a screen reader asks for one.
  _semanticsHandle ??= SemanticsBinding.instance.ensureSemantics();

  registerMarionetteExtension(
    name: 'a11y.snapshot',
    description:
        'What a screen reader announces on the current screen, in swipe order, plus the semantics nodes. '
        'Compare with a screenshot: anything visible but missing from the transcript is invisible to blind users.',
    inputSchema: const ExtensionInputSchema(
      properties: {
        'locale': ExtensionParam.string(
          description: 'Language of role and state words.',
          enumValues: ['pl', 'en'],
          defaultValue: 'pl',
        ),
        'includeRects': ExtensionParam.boolean(
          description: 'Add logical-pixel rects [left, top, width, height] to nodes.',
          defaultValue: false,
        ),
      },
    ),
    callback: (params) async {
      final snapshot = await _freshSnapshot();

      return MarionetteExtensionResult.success(
        snapshot.toJson(locale: params['locale'] ?? 'pl', includeRects: params['includeRects'] == 'true'),
      );
    },
  );

  registerMarionetteExtension(
    name: 'a11y.audit',
    description:
        'Runs automated WCAG 2.2 checks on the current screen. They cover only part of WCAG: '
        'still judge whether names make sense and the reading order is logical from a11y.snapshot.',
    inputSchema: const ExtensionInputSchema(),
    callback: (_) async {
      final findings = A11yAudit.run(await _freshSnapshot());

      return MarionetteExtensionResult.success({
        'errors': findings.where((finding) => finding.severity == A11ySeverity.error).length,
        'warnings': findings.where((finding) => finding.severity == A11ySeverity.warning).length,
        'findings': [for (final finding in findings) finding.toJson()],
      });
    },
  );
}

Future<A11ySnapshot> _freshSnapshot() async {
  SchedulerBinding.instance.scheduleFrame();
  await SchedulerBinding.instance.endOfFrame;

  return A11ySnapshot.capture();
}
