import 'package:flutter/rendering.dart';

import 'a11y_node.dart';
import 'screen_reader_announcer.dart';

class A11ySnapshot {
  const A11ySnapshot(this.nodes);

  /// Reads the live semantics tree. Empty unless semantics are enabled.
  factory A11ySnapshot.capture() {
    final nodes = <A11yNode>[];
    for (final view in RendererBinding.instance.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      // The tree is in physical pixels; rules need logical ones.
      final toLogical = 1 / view.flutterView.devicePixelRatio;
      if (root != null) _collect(root, Matrix4.diagonal3Values(toLogical, toLogical, 1), nodes);
    }

    return A11ySnapshot(nodes);
  }

  /// Nodes a screen reader can focus, in swipe order.
  final List<A11yNode> nodes;

  List<String> transcript({String locale = 'pl'}) {
    final announcer = ScreenReaderAnnouncer(locale: locale);

    return [
      for (final node in nodes)
        if (!node.offscreen) announcer.announce(node),
    ];
  }

  Map<String, Object?> toJson({String locale = 'pl', bool includeRects = false}) => {
    'transcript': transcript(locale: locale),
    'nodes': [for (final node in nodes) node.toJson(includeRect: includeRects)],
  };

  static void _collect(SemanticsNode node, Matrix4 toGlobal, List<A11yNode> out) {
    final descendants = <A11yNode>[];
    for (final child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      if (child.isMergedIntoParent) continue;
      final childTransform = child.transform;
      _collect(child, childTransform == null ? toGlobal : toGlobal.multiplied(childTransform), descendants);
    }

    final a11yNode = A11yNode.fromSemantics(
      node,
      MatrixUtils.transformRect(toGlobal, node.rect),
      hasNamedDescendants: descendants.any((descendant) => descendant.hasContent),
    );
    if (!node.isInvisible && (a11yNode.hasContent || a11yNode.isTappable)) out.add(a11yNode);
    out.addAll(descendants);
  }
}
