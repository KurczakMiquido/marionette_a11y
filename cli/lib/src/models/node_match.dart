/// A Flutter node paired with the native node that shows it.
class NodeMatch {
  const NodeMatch({required this.flutterId, required this.nativePath, required this.by});

  static const byIdentifier = 'identifier';
  static const byRect = 'rect';

  final int flutterId;
  final String nativePath;

  /// [byIdentifier] or [byRect].
  final String by;

  Map<String, dynamic> toJson() => {'flutterId': flutterId, 'nativePath': nativePath, 'by': by};
}
