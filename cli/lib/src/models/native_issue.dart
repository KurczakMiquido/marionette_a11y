import 'a11y_rect.dart';

/// An issue reported by the platform's own checks (ATF on Android, Apple audit on iOS).
class NativeIssue {
  const NativeIssue({
    required this.source,
    required this.check,
    required this.severity,
    required this.message,
    this.nodePath,
    this.rect,
  });

  factory NativeIssue.fromJson(Map<String, dynamic> json) => NativeIssue(
    source: json['source'] as String,
    check: json['check'] as String,
    severity: json['severity'] as String,
    message: json['message'] as String,
    nodePath: json['nodePath'] as String?,
    rect: json['rect'] == null ? null : A11yRect.fromList(json['rect'] as List),
  );

  final String source;
  final String check;
  final String severity;
  final String message;
  final String? nodePath;
  final A11yRect? rect;

  Map<String, dynamic> toJson() => {
    'source': source,
    'check': check,
    'severity': severity,
    'message': message,
    'nodePath': nodePath,
    'rect': rect?.toList(),
  };
}
