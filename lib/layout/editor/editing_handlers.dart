import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pancake_annotation_lite/models/bbox.dart';
import 'package:pancake_annotation_lite/models/annotation.dart';

abstract class EditingHandlerModel {
  AnnotationData annotationData;

  EditingHandlerModel({
    required this.annotationData,
  });

  static double pointToLineSegmentDistance(
      Offset p, Offset v, Offset w, bool useManhattanDistance) {
    // 计算线段长度的平方
    double l2 = (w - v).distanceSquared;

    if (l2 == 0.0) {
      // v == w 时，退化为点
      return useManhattanDistance
          ? (p - v).dx.abs() + (p - v).dy.abs()
          : (p - v).distance;
    }

    // 投影点 p 到线段 vw 上，计算投影比例 t
    double t = ((p - v).dx * (w - v).dx + (p - v).dy * (w - v).dy) / l2;
    t = math.max(0, math.min(1, t));

    // 计算投影点
    Offset projection =
        Offset(v.dx + t * (w.dx - v.dx), v.dy + t * (w.dy - v.dy));

    return useManhattanDistance
        ? (p - projection).dx.abs() + (p - projection).dy.abs()
        : (p - projection).distance;
  }

  static double pointToPointDistance(
      Offset p1, Offset p2, bool useManhattanDistance) {
    return useManhattanDistance
        ? (p1 - p2).dx.abs() + (p1 - p2).dy.abs()
        : (p1 - p2).distance;
  }

  static bool isPointInSquare(Offset center, double sideLength, Offset point) {
    double halfSide = sideLength / 2;

    // 正方形的边界
    final double left = center.dx - halfSide;
    final double right = center.dx + halfSide;
    final double top = center.dy - halfSide;
    final double bottom = center.dy + halfSide;

    // 检查点是否在边界内
    return (point.dx >= left &&
        point.dx <= right &&
        point.dy >= top &&
        point.dy <= bottom);
  }

  SystemMouseCursor onHover({Offset? canvasPosition}) {
    return SystemMouseCursors.basic;
  }

  void onHoverExit() {
    return;
  }

  bool onPanStart({Offset? canvasPosition}) {
    return false;
  }

  void onPanUpdate({Offset? canvasPosition}) {
    return;
  }

  void onPanEnd() {
    return;
  }

  bool onClick({Offset? canvasPosition}) {
    return false;
  }
}

class EditingHandlers extends EditingHandlerModel {
  Map<Type, EditingHandlerModel> handlers = {};
  final bool useManhattanDistance;

  EditingHandlers({
    required super.annotationData,
    double nodeHitboxRadius = 10,
    double lineHitboxRadius = 3,
    this.useManhattanDistance = true,
  }) {
    handlers[BBox] = BBoxEditingHandler(
      annotationData: annotationData,
      nodeHitboxRadius: nodeHitboxRadius,
      lineHitboxRadius: lineHitboxRadius,
    );
  }

  void reloadAnnotationData(AnnotationData annotationData) {
    this.annotationData = annotationData;
    for (EditingHandlerModel handler in handlers.values) {
      handler.annotationData = annotationData;
    }
  }

  @override
  SystemMouseCursor onHover({Offset? canvasPosition}) {
    EditingHandlerModel? handler =
        handlers[annotationData.createdAnnotation.runtimeType];
    if (handler != null) return handler.onHover(canvasPosition: canvasPosition);
    handler = handlers[annotationData.selectedAnnotation.runtimeType];
    if (handler == null) return SystemMouseCursors.basic;
    return handler.onHover(canvasPosition: canvasPosition);
  }

  @override
  void onHoverExit() {
    EditingHandlerModel? handler =
        handlers[annotationData.createdAnnotation.runtimeType];
    if (handler != null) return handler.onHoverExit();
    handler = handlers[annotationData.selectedAnnotation.runtimeType];
    if (handler == null) return;
    handler.onHoverExit();
  }

  @override
  bool onPanStart({Offset? canvasPosition}) {
    EditingHandlerModel? handler =
        handlers[annotationData.createdAnnotation.runtimeType];
    if (handler != null)
      return handler.onPanStart(canvasPosition: canvasPosition);
    handler = handlers[annotationData.selectedAnnotation.runtimeType];
    if (handler == null) return false;
    return handler.onPanStart(canvasPosition: canvasPosition);
  }

  @override
  void onPanUpdate({Offset? canvasPosition}) {
    EditingHandlerModel? handler =
        handlers[annotationData.createdAnnotation.runtimeType];
    if (handler != null)
      return handler.onPanUpdate(canvasPosition: canvasPosition);
    handler = handlers[annotationData.selectedAnnotation.runtimeType];
    if (handler == null) return;
    handler.onPanUpdate(canvasPosition: canvasPosition);
  }

  @override
  void onPanEnd() {
    EditingHandlerModel? handler =
        handlers[annotationData.createdAnnotation.runtimeType];
    if (handler != null) return handler.onPanEnd();
    handler = handlers[annotationData.selectedAnnotation.runtimeType];
    if (handler == null) return;
    handler.onPanEnd();
  }
}

enum BBoxEditingMode {
  block,
  node,
  line,
  annotation,
  create,
}

class BBoxEditingHandler extends EditingHandlerModel {
  final double nodeHitboxRadius;
  final double lineHitboxRadius;
  final bool useCircleHitBox;

  BBoxEditingMode mode = BBoxEditingMode.block;
  int editingNodeIndex = -1;
  int editingLineIndex = -1;
  BBox? editingBBox;
  Offset? scaleFrom;

  BBoxEditingHandler({
    required super.annotationData,
    this.nodeHitboxRadius = 10.0,
    this.lineHitboxRadius = 3.0,
    // this.useManhattanDistance = true,
    this.useCircleHitBox = false,
  });

  int nodeHitTest(Offset canvasPosition) {
    if (annotationData.selectedAnnotation is! BBox) return -1;
    final List<Offset> nodes = annotationData.selectedAnnotation!.nodes;
    for (int i = 0; i < nodes.length; i++) {
      final isHit = useCircleHitBox
          ? EditingHandlerModel.pointToPointDistance(
                  nodes[i], canvasPosition, !useCircleHitBox) <
              nodeHitboxRadius
          : EditingHandlerModel.isPointInSquare(
              nodes[i], nodeHitboxRadius, canvasPosition);
      if (isHit) {
        return i;
      }
    }
    return -1;
  }

  int lineHitTest(Offset canvasPosition, {double threshold = 1.0}) {
    if (annotationData.selectedAnnotation is! BBox) return -1;
    final List<List<Offset>> lines = annotationData.selectedAnnotation!.lines;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].length < 2) continue; // 确保线段有两个点
      final distance = EditingHandlerModel.pointToLineSegmentDistance(
          canvasPosition, lines[i][0], lines[i][1], !useCircleHitBox);
      if (distance < lineHitboxRadius * threshold) {
        return i;
      }
    }
    return -1;
  }

  void reloadAnnotationData(AnnotationData annotationData) {
    this.annotationData = annotationData;
  }

  @override
  SystemMouseCursor onHover({Offset? canvasPosition}) {
    if (annotationData.selectedAnnotation is! BBox)
      return SystemMouseCursors.basic;
    if (canvasPosition == null) return SystemMouseCursors.basic;

    final int hitNodeIndex = nodeHitTest(canvasPosition);
    editingNodeIndex = hitNodeIndex;
    switch (hitNodeIndex) {
      case -1:
        break;
      case 0:
        return SystemMouseCursors.resizeUpLeft;
      case 1:
        return SystemMouseCursors.resizeUpRight;
      case 2:
        return SystemMouseCursors.resizeDownRight;
      case 3:
        return SystemMouseCursors.resizeDownLeft;
    }

    final int hitLineIndex = lineHitTest(canvasPosition);
    editingLineIndex = hitLineIndex;
    switch (hitLineIndex) {
      case -1:
        break;
      case 0:
        return SystemMouseCursors.resizeUp;
      case 1:
        return SystemMouseCursors.resizeRight;
      case 2:
        return SystemMouseCursors.resizeDown;
      case 3:
        return SystemMouseCursors.resizeLeft;
    }

    if (annotationData.selectedAnnotation!.path.contains(canvasPosition)) {
      return SystemMouseCursors.allScroll;
    }

    return SystemMouseCursors.basic;
  }

  @override
  bool onPanStart({Offset? canvasPosition}) {
    if (canvasPosition == null ||
        (annotationData.selectedAnnotation is! BBox &&
            annotationData.createdAnnotation is! BBox)) {
      mode = BBoxEditingMode.block;
      editingNodeIndex = -1;
      editingLineIndex = -1;
      editingBBox = null;
      return false;
    }

    if (annotationData.createdAnnotation != null) {
      mode = BBoxEditingMode.create;
      editingBBox = BBox.fromLTWH(
        category: annotationData.createdAnnotation!.category,
        left: canvasPosition.dx,
        top: canvasPosition.dy,
        width: 0,
        height: 0,
      );
      return true;
    }

    BBox bbox = annotationData.selectedAnnotation! as BBox;
    if (editingNodeIndex != -1) {
      editingBBox = bbox;
      mode = BBoxEditingMode.node;
      return true;
    } else if (editingLineIndex != -1) {
      editingBBox = bbox;
      mode = BBoxEditingMode.line;
      return true;
    }

    final int hitNodeIndex = nodeHitTest(canvasPosition);
    if (hitNodeIndex != -1) {
      editingNodeIndex = hitNodeIndex;
      editingBBox = bbox;
      mode = BBoxEditingMode.node;
      return true;
    }

    final int hitLineIndex = lineHitTest(canvasPosition);
    if (hitLineIndex != -1) {
      editingLineIndex = hitLineIndex;
      editingBBox = bbox;
      mode = BBoxEditingMode.line;
      return true;
    }

    if (bbox.rect.contains(canvasPosition)) {
      mode = BBoxEditingMode.annotation;
      // editingNodeIndex = -1;
      editingBBox = bbox;
      scaleFrom = canvasPosition;
      return true;
    }

    mode = BBoxEditingMode.block;
    editingNodeIndex = -1;
    editingLineIndex = -1;
    editingBBox = null;
    return false;
  }

  @override
  void onHoverExit() {
    // mode = BBoxEditingMode.block;
    // editingNodeIndex = -1;
    // editingLineIndex = -1;
    // editingBBox = null;
    // scaleFrom = null;
    return;
  }

  @override
  void onPanUpdate({Offset? canvasPosition}) {
    if (canvasPosition == null ||
        mode == BBoxEditingMode.block ||
        editingBBox == null ||
        (annotationData.selectedAnnotation is! BBox &&
            annotationData.createdAnnotation is! BBox)) return;

    // 初始化边界值
    double left = editingBBox!.left;
    double top = editingBBox!.top;
    double right = editingBBox!.right;
    double bottom = editingBBox!.bottom;

    switch (mode) {
      case BBoxEditingMode.node:
        // 当出于节点编辑模式时，根据当前选择的节点更新边界值
        switch (editingNodeIndex) {
          case -1:
            mode = BBoxEditingMode.block;
            return;
          case 0:
            left = canvasPosition.dx;
            top = canvasPosition.dy;
            break;
          case 1:
            top = canvasPosition.dy;
            right = canvasPosition.dx;
            break;
          case 2:
            right = canvasPosition.dx;
            bottom = canvasPosition.dy;
            break;
          case 3:
            left = canvasPosition.dx;
            bottom = canvasPosition.dy;
            break;
        }
      // 当出于线段编辑模式时，根据当前选择的线段更新边界值
      case BBoxEditingMode.line:
        switch (editingLineIndex) {
          case -1:
            mode = BBoxEditingMode.block;
            return;
          case 0:
            top = canvasPosition.dy;
            break;
          case 1:
            right = canvasPosition.dx;
            break;
          case 2:
            bottom = canvasPosition.dy;
            break;
          case 3:
            left = canvasPosition.dx;
            break;
        }
      case BBoxEditingMode.annotation:
        if (scaleFrom == null) return;
        final dx = canvasPosition.dx - scaleFrom!.dx;
        final dy = canvasPosition.dy - scaleFrom!.dy;
        left += dx;
        right += dx;
        top += dy;
        bottom += dy;
        break;
      case BBoxEditingMode.create:
        right = canvasPosition.dx;
        bottom = canvasPosition.dy;
        break;
      case BBoxEditingMode.block:
        return;
    }

    // 将边界值限制在图像范围内
    left = left.clamp(0, annotationData.imageWidth.toDouble());
    top = top.clamp(0, annotationData.imageHeight.toDouble());
    right = right.clamp(0, annotationData.imageWidth.toDouble());
    bottom = bottom.clamp(0, annotationData.imageHeight.toDouble());

    final BBox newBBox = BBox(
      category: editingBBox!.category,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
    );

    // 更新标注
    if (mode == BBoxEditingMode.block) {
      return;
    } else if (mode == BBoxEditingMode.create) {
      annotationData.updateCreatingAnnotation(newBBox);
    } else {
      annotationData.updateSelectingAnnotation(newBBox);
    }
  }

  @override
  void onPanEnd() {
    if (mode == BBoxEditingMode.create) {
      annotationData.finishCreatingAnnotation();
    } else if (mode == BBoxEditingMode.annotation ||
        mode == BBoxEditingMode.node ||
        mode == BBoxEditingMode.line) {
      // annotationData.finishSelectingAnnotation();
      // 如果在编辑中,就拍摄快照
      annotationData.snapshotSelectingAnnotation();
    } else {
      // 如果不在上述情况中,看起来就不该当前函数来管
      return;
    }

    mode = BBoxEditingMode.block;
    editingNodeIndex = -1;
    editingLineIndex = -1;
    editingBBox = null;
    scaleFrom = null;
  }
}
