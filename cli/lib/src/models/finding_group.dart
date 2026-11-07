import 'a11y_rect.dart';
import 'check_report.dart';
import 'finding.dart';

/// Findings about one element, drawn as one numbered box in the HTML report; or the findings about the whole screen.
class FindingGroup {
  const FindingGroup({required this.number, required this.findings, this.flutterId, this.nativePath, this.rect});

  /// 1..n in report order; null for the whole-screen group, which has no box.
  final int? number;
  final List<Finding> findings;

  /// The Flutter node the findings are about, when known.
  final int? flutterId;

  /// The native node the findings are about, when no Flutter node is known.
  final String? nativePath;

  /// The box: the rect of the first finding that has one. Null for the whole screen.
  final A11yRect? rect;

  /// The worst severity among [findings].
  String get severity => findings.map((f) => f.severity).reduce((a, b) => _rank(a) <= _rank(b) ? a : b);

  static int _rank(String severity) {
    final i = Finding.severities.indexOf(severity);
    return i < 0 ? Finding.severities.length : i;
  }

  /// Groups [report]'s findings by target: the Flutter id, else the Flutter id matched to the native path, else the
  /// native path, else the rect rounded to whole points. Numbered by worst severity, then top, then left. Findings
  /// whose target has no rect come last in one unnumbered group.
  static List<FindingGroup> of(CheckReport report) {
    final flutterIdByPath = {for (final m in report.matches) m.nativePath: m.flutterId};
    int? flutterIdOf(Finding f) => f.flutterId ?? flutterIdByPath[f.nativePath];
    String? targetOf(Finding f) {
      final flutterId = flutterIdOf(f);
      if (flutterId != null) return 'flutter:$flutterId';
      if (f.nativePath != null) return 'native:${f.nativePath}';
      return f.rect == null ? null : 'rect:${f.rect!.toList().map((v) => v.round()).join(',')}';
    }

    final byTarget = <String, List<Finding>>{};
    for (final f in report.findings) {
      final target = targetOf(f);
      if (target != null) byTarget.putIfAbsent(target, () => []).add(f);
    }
    final boxed = <FindingGroup>[];
    for (final findings in byTarget.values) {
      final rect = findings.map((f) => f.rect).nonNulls.firstOrNull;
      if (rect == null) continue;
      final flutterId = flutterIdOf(findings.first);
      final nativePath = flutterId == null ? findings.first.nativePath : null;
      boxed.add(
        FindingGroup(number: null, findings: findings, flutterId: flutterId, nativePath: nativePath, rect: rect),
      );
    }
    final inBox = Set<Finding>.identity()..addAll(boxed.expand((g) => g.findings));
    final screen = [
      for (final f in report.findings)
        if (!inBox.contains(f)) f,
    ];

    int compare(FindingGroup a, FindingGroup b) {
      final bySeverity = _rank(a.severity).compareTo(_rank(b.severity));
      if (bySeverity != 0) return bySeverity;
      final byTop = a.rect!.top.compareTo(b.rect!.top);
      if (byTop != 0) return byTop;
      final byLeft = a.rect!.left.compareTo(b.rect!.left);
      // List.sort is not stable; the first appearance decides between equal boxes.
      return byLeft != 0 ? byLeft : boxed.indexOf(a).compareTo(boxed.indexOf(b));
    }

    return [
      for (final (i, g) in ([...boxed]..sort(compare)).indexed)
        FindingGroup(
          number: i + 1,
          findings: g.findings,
          flutterId: g.flutterId,
          nativePath: g.nativePath,
          rect: g.rect,
        ),
      if (screen.isNotEmpty) FindingGroup(number: null, findings: screen),
    ];
  }
}
