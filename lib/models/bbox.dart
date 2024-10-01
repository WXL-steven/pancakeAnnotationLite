import 'dart:ui';
import 'package:pancake_annotation_lite/models/base.dart';

class BBox extends Annotation {
  late double left;
  late double top;
  late double width;
  late double height;

  @override
  final Category category;
  @override
  late final Path path;

  late final Rect rect;

  /// Creates a bounding box using [left], [top], [right], and [bottom].
  /// Ensures [right] and [bottom] are truly the bottom-right corner.
  BBox({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required this.category,
  })  : left = left < right ? left : right,
        top = top < bottom ? top : bottom,
        width = (right - left).abs(),
        height = (bottom - top).abs() {
    _initialize();
  }

  /// Creates a bounding box using [left], [top], [width], and [height].
  /// Adjusts if [width] or [height] are negative.
  BBox.fromLTWH({
    required double left,
    required double top,
    required double width,
    required double height,
    required this.category,
  })  : left = width >= 0 ? left : left + width,
        top = height >= 0 ? top : top + height,
        width = width.abs(),
        height = height.abs() {
    _initialize();
  }

  /// Creates a bounding box from a list of [Offset] nodes.
  /// Determines the bounding box by finding the min/max x and y values.
  BBox.fromNodes({
    required List<Offset> nodes,
    required this.category,
  }) {
    if (nodes.length < 4)
      throw Exception('Must have at least 4 nodes to create a BBox');
    double minX = nodes.first.dx;
    double maxX = nodes.first.dx;
    double minY = nodes.first.dy;
    double maxY = nodes.first.dy;
    for (var node in nodes) {
      if (node.dx < minX) minX = node.dx;
      if (node.dx > maxX) maxX = node.dx;
      if (node.dy < minY) minY = node.dy;
      if (node.dy > maxY) maxY = node.dy;
    }
    left = minX;
    top = minY;
    width = maxX - minX;
    height = maxY - minY;

    _initialize();
  }

  void _initialize() {
    rect = Rect.fromLTWH(left, top, width, height);
    path = Path()..addRect(rect);
  }

  /// Returns the right coordinate.
  double get right => left + width;

  /// Returns the bottom coordinate.
  double get bottom => top + height;

  /// Returns the x-coordinate of the center.
  double get xCenter => left + width / 2;

  /// Returns the y-coordinate of the center.
  double get yCenter => top + height / 2;

  /// Returns whether the bounding box is valid(too small).
  @override
  bool get valid => width > 2 && height > 2;

  @override
  List<Offset> get nodes {
    return [
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
    ];
  }

  @override
  List<List<Offset>> get lines {
    List<Offset> nodes = this.nodes;
    return [
      [nodes[0], nodes[1]],
      [nodes[1], nodes[2]],
      [nodes[2], nodes[3]],
      [nodes[3], nodes[0]],
    ];
  }

  @override
  String toString() =>
      "BBox[${category.name}]:(L: $left, T: $top, W: $width, H: $height)";
}
