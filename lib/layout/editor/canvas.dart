import 'package:flutter/material.dart';
import 'package:pancake_annotation_lite/models/base.dart';
import 'dart:ui' as ui;

import 'package:pancake_annotation_lite/models/bbox.dart';
import 'package:pancake_annotation_lite/models/annotation.dart';
import 'package:pancake_annotation_lite/layout/editor/painters.dart';

class AnnotationCanvas extends StatelessWidget {
  final AnnotationData annotationData;
  final double hoverAnimationValue;

  const AnnotationCanvas({
    super.key,
    required this.annotationData,
    this.hoverAnimationValue = 0.0,
  });

  Widget _buildCanvas(BuildContext context, Widget? child) {
    return CustomPaint(
      size: Size(annotationData.imageWidth.toDouble(),
          annotationData.imageHeight.toDouble()),
      painter: ImagePainter(annotationData.image),
      foregroundPainter: AnnotationPainter(
        annotationData.annotations,
        annotationData.selectedAnnotation,
        annotationData.hoveredAnnotation,
        annotationData.createdAnnotation,
        hoverAnimationValue: hoverAnimationValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: annotationData,
      builder: _buildCanvas,
    );
  }
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // 绘制图像
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class AnnotationPainter extends CustomPainter {
  final List<Annotation> annotations;
  final Annotation? selectedAnnotation;
  final Annotation? hoverAnnotation;
  final Annotation? createdAnnotation;
  final double hoverAnimationValue;
  late BoxPainters boxPainters;

  AnnotationPainter(this.annotations, this.selectedAnnotation,
      this.hoverAnnotation, this.createdAnnotation,
      {this.hoverAnimationValue = 0.0}) {
    boxPainters = BoxPainters();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 逻辑：
    // 如果有选中的就不绘制悬停了
    // 最后绘制选中或者悬停

    for (Annotation annotation in annotations) {
      // ~~如果当前标注被选中，则跳过~~
      // 现在不需要此行为,因为选中的标注会从List中删除
      // if (identical(selectedAnnotation, annotation)) continue;
      // 如果当前标注被悬停且没有任何标注被选中且也没有创建中的标注，则跳过
      if (hoverAnnotation == annotation &&
          selectedAnnotation == null &&
          createdAnnotation == null) continue;

      // 如果决定要绘制，那么至少肯定要绘制边框
      if (annotation is BBox) boxPainters.border(canvas, annotation);
      // 如果没有选中或者悬停中，那么绘制覆盖
      if (selectedAnnotation == null &&
          hoverAnnotation == null &&
          createdAnnotation == null) {
        if (annotation is BBox) boxPainters.overlay(canvas, annotation);
      }
    }

    // 最后绘制创建,选中或者悬停
    if (createdAnnotation != null) {
      if (createdAnnotation is BBox) {
        // 如果RTLB都<=0，则不绘制
        final BBox createdAnnotation = this.createdAnnotation! as BBox;
        if (createdAnnotation.left <= 0 &&
            createdAnnotation.top <= 0 &&
            createdAnnotation.right <= 0 &&
            createdAnnotation.bottom <= 0) return;
        boxPainters.created(canvas, createdAnnotation);
      }
    } else if (selectedAnnotation != null) {
      if (selectedAnnotation is BBox) {
        boxPainters.selected(canvas, selectedAnnotation! as BBox);
      } else {
        // Coming soon
      }
    } else if (hoverAnnotation != null) {
      if (hoverAnnotation is BBox) {
        boxPainters.highlight(canvas, size, hoverAnnotation! as BBox,
            hoverAnimationValue: hoverAnimationValue);
      } else {
        // Coming soon
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // return true;
    // 如果`annotations`、``selectedAnnotation`、`hoverAnnotation`之一发生了变化
    // 则重绘
    if (oldDelegate is AnnotationPainter) {
      return oldDelegate.annotations != annotations ||
          oldDelegate.selectedAnnotation != selectedAnnotation ||
          oldDelegate.hoverAnnotation != hoverAnnotation ||
          oldDelegate.hoverAnimationValue != hoverAnimationValue;
    } else {
      return true;
    }
  }
}
