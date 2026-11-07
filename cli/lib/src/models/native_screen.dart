/// Screen size in logical points; `scale` is physical pixels per point.
class NativeScreen {
  const NativeScreen({required this.width, required this.height, required this.scale});

  factory NativeScreen.fromJson(Map<String, dynamic> json) => NativeScreen(
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    scale: (json['scale'] as num).toDouble(),
  );

  final double width;
  final double height;
  final double scale;

  Map<String, dynamic> toJson() => {'width': width, 'height': height, 'scale': scale};
}
