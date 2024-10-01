import 'package:flutter/material.dart';
// import 'dart:ui' as ui;

import 'package:pancake_annotation_lite/models/bbox.dart';
// import 'package:pancake_annotation_lite/models/annotation.dart';

class BoxPainters {
  final double lineWidth;
  final double overlayOpacity;
  final double highlightOpacity;
  final double selectedOpacity;
  final double selectedRadius;
  final bool selectedDrawCircle;

  late Paint borderPaint;
  late Paint overlayPaint;
  late Paint highlightPaint;
  late Paint highlightEraser;
  late Paint selectedNodePaint;
  late Paint selectedOverlayPaint;

  BoxPainters({
    this.lineWidth = 1.0,
    this.overlayOpacity = 0.2,
    this.highlightOpacity = 0.5,
    this.selectedOpacity = 0.5,
    this.selectedRadius = 10.0,
    this.selectedDrawCircle = false,
    // Color borderColor = Colors.redAccent,
    Color selectedNodeColor = Colors.black,
    Color selectedOverlayColor = Colors.white70,
    Color highlightColor = Colors.black12,
    // Color selectedColor = Colors.blueAccent,
  }) {
    borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    overlayPaint = Paint()..style = PaintingStyle.fill;

    highlightPaint = Paint()
      ..color = highlightColor.withOpacity(highlightOpacity);

    highlightEraser = Paint()..blendMode = BlendMode.clear;

    selectedNodePaint = Paint()
      // TODO: Do something
      ..color = selectedNodeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;

    selectedOverlayPaint = Paint()
      ..color = selectedOverlayColor.withOpacity(selectedOpacity)
      ..style = PaintingStyle.fill;
  }

  void border(Canvas canvas, BBox bbox) {
    borderPaint.color = bbox.category.color;
    canvas.drawRect(bbox.rect, borderPaint);
  }

  void overlay(Canvas canvas, BBox bbox) {
    overlayPaint.color = bbox.category.color.withOpacity(overlayOpacity);
    canvas.drawRect(bbox.rect, overlayPaint);
  }

  void highlight(Canvas canvas, Size size, BBox bbox,
      {double hoverAnimationValue = 1.0}) {
    highlightPaint.color = highlightPaint.color
        .withOpacity(highlightOpacity * hoverAnimationValue);
    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, highlightPaint);
    canvas.drawRect(bbox.rect, highlightEraser);
    canvas.restore();
    border(canvas, bbox);
  }

  void selected(Canvas canvas, BBox bbox) {
    border(canvas, bbox);

    for (Offset offset in bbox.nodes) {
      if (selectedDrawCircle) {
        canvas.drawCircle(offset, selectedRadius, selectedOverlayPaint);
        canvas.drawCircle(offset, selectedRadius, selectedNodePaint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(
                center: offset, width: selectedRadius, height: selectedRadius),
            selectedOverlayPaint);
        canvas.drawRect(
            Rect.fromCenter(
                center: offset, width: selectedRadius, height: selectedRadius),
            selectedNodePaint);
      }
    }
  }

  void created(Canvas canvas, BBox bbox) {
    selected(canvas, bbox);
  }
}
