import 'finding.dart';
import 'flutter_node.dart';
import 'native_tree.dart';
import 'node_match.dart';

/// A whole `a11y-check/v1` document: both trees, how they were matched and what disagrees.
class CheckReport {
  const CheckReport({
    required this.flutterNodes,
    required this.native,
    required this.matches,
    required this.findings,
    this.transcript = const [],
  });

  static const schema = 'a11y-check/v1';
  static const _knownSeverities = ['error', 'warning', 'info'];

  final List<FlutterNode> flutterNodes;
  final NativeTree native;
  final List<NodeMatch> matches;
  final List<Finding> findings;

  /// What the screen reader announces, in swipe order.
  final List<String> transcript;

  /// The same report with the in-app audit [flutterFindings] first and the Flutter [transcript].
  CheckReport withFlutter({required List<Finding> flutterFindings, required List<String> transcript}) => CheckReport(
    flutterNodes: flutterNodes,
    native: native,
    matches: matches,
    findings: [...flutterFindings, ...findings],
    transcript: transcript,
  );

  Map<String, dynamic> toJson() => {
    'schema': schema,
    'platform': native.platform,
    'app': native.app,
    'flutter': {
      'nodes': [for (final n in flutterNodes) n.toJson()],
      'transcript': transcript,
    },
    'native': native.toJson(),
    'matches': [for (final m in matches) m.toJson()],
    'findings': [for (final f in findings) f.toJson()],
  };

  /// Counts per severity, then one `[severity] rule — message` line per finding.
  String summary() {
    final counts = {for (final s in _knownSeverities) s: 0};
    for (final f in findings) {
      counts[f.severity] = (counts[f.severity] ?? 0) + 1;
    }
    final out = StringBuffer()..writeln([for (final e in counts.entries) '${e.key}: ${e.value}'].join(', '));
    for (final f in findings) {
      // Engine messages may span lines; the summary keeps one line per finding.
      out.writeln('[${f.severity}] ${f.rule} — ${f.message.replaceAll(RegExp(r'\s+'), ' ').trim()}');
    }
    return out.toString();
  }
}
