import 'native_issue.dart';
import 'native_node.dart';
import 'native_screen.dart';

/// A whole `a11y-native/v1` document.
class NativeTree {
  const NativeTree({
    required this.platform,
    required this.device,
    required this.app,
    required this.screen,
    required this.nodes,
    required this.issues,
  });

  factory NativeTree.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != schema) {
      throw FormatException('Unsupported native schema: ${json['schema']}, expected $schema');
    }
    return NativeTree(
      platform: json['platform'] as String,
      device: json['device'] as String,
      app: json['app'] as String,
      screen: NativeScreen.fromJson(json['screen'] as Map<String, dynamic>),
      nodes: [for (final n in json['nodes'] as List) NativeNode.fromJson(n as Map<String, dynamic>)],
      issues: [for (final i in json['issues'] as List) NativeIssue.fromJson(i as Map<String, dynamic>)],
    );
  }

  static const schema = 'a11y-native/v1';

  final String platform;
  final String device;
  final String app;
  final NativeScreen screen;
  final List<NativeNode> nodes;
  final List<NativeIssue> issues;

  Map<String, dynamic> toJson() => {
        'schema': schema,
        'platform': platform,
        'device': device,
        'app': app,
        'screen': screen.toJson(),
        'nodes': [for (final n in nodes) n.toJson()],
        'issues': [for (final i in issues) i.toJson()],
      };
}
