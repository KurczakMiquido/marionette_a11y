import 'a11y_rect.dart';

/// One problem in an `a11y-check/v1` report: a cross-check rule or a native issue passed through.
class Finding {
  const Finding({
    required this.rule,
    required this.source,
    required this.severity,
    required this.message,
    this.flutterId,
    this.nativePath,
    this.rect,
  });

  final String rule;

  /// `crosscheck`, or the native issue's source (`atf`, `apple`).
  final String source;
  final String severity;
  final String message;
  final int? flutterId;
  final String? nativePath;
  final A11yRect? rect;

  Map<String, dynamic> toJson() => {
    'rule': rule,
    'source': source,
    'severity': severity,
    'message': message,
    'flutterId': ?flutterId,
    'nativePath': ?nativePath,
    'rect': ?rect?.toList(),
  };
}
