import 'dart:math' as math;

/// Rectangle in logical points: left, top, width, height.
class A11yRect {
  const A11yRect(this.left, this.top, this.width, this.height);

  factory A11yRect.fromList(List<dynamic> list) {
    if (list.length != 4) {
      throw FormatException('rect needs 4 numbers, got ${list.length}');
    }
    final v = list.map((e) => (e as num).toDouble()).toList();
    return A11yRect(v[0], v[1], v[2], v[3]);
  }

  final double left;
  final double top;
  final double width;
  final double height;

  List<double> toList() => [left, top, width, height];

  /// Intersection over union; 0 when disjoint or when both rects are empty.
  double iou(A11yRect other) {
    final w = math.min(left + width, other.left + other.width) - math.max(left, other.left);
    final h = math.min(top + height, other.top + other.height) - math.max(top, other.top);
    if (w <= 0 || h <= 0) return 0;
    final inter = w * h;
    final union = width * height + other.width * other.height - inter;
    return union <= 0 ? 0 : inter / union;
  }

  @override
  bool operator ==(Object other) =>
      other is A11yRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'A11yRect($left, $top, $width, $height)';
}
