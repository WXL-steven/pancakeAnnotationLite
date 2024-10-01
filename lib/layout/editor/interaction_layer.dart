import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pancake_annotation_lite/models/base.dart';
import 'package:pancake_annotation_lite/models/annotation.dart';
import 'package:pancake_annotation_lite/layout/editor/editing_handlers.dart';

class AnnotationInteractionLayer extends StatefulWidget {
  final AnnotationData annotationData;
  final GlobalKey canvasKey;
  final AnimationController? hoverAnimationController;
  final void Function(PointerScrollEvent)? onScroll;
  final void Function(ScaleStartDetails)? onTorchScaleStart;
  final void Function(ScaleUpdateDetails)? onTorchScaleUpdate;
  final void Function(ScaleEndDetails)? onTorchScaleEnd;

  const AnnotationInteractionLayer({
    super.key,
    required this.annotationData,
    required this.canvasKey,
    this.hoverAnimationController,
    this.onScroll,
    this.onTorchScaleStart,
    this.onTorchScaleUpdate,
    this.onTorchScaleEnd,
  });

  @override
  State<AnnotationInteractionLayer> createState() =>
      _AnnotationInteractionLayerState();
}

enum ScaleType {
  forward,
  block,
  // canvas,
  // node,
  annotation,
}

class _AnnotationInteractionLayerState
    extends State<AnnotationInteractionLayer> {
  bool isScalingAnnotation = false;
  ScaleType scalingMode = ScaleType.forward;
  SystemMouseCursor currentCursor = SystemMouseCursors.basic;

  late BBoxEditingHandler editingHandlers;

  @override
  void initState() {
    super.initState();
    editingHandlers = BBoxEditingHandler(
      annotationData: widget.annotationData,
      nodeHitboxRadius: 20.0,
      lineHitboxRadius: 5.0,
    );
  }

  // 转换全局坐标到画布坐标
  Offset? globalToCanvas(Offset globalPoint) {
    final RenderBox? renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.globalToLocal(globalPoint);
    } else {
      return null;
    }
  }

  // 重要工具，用于判断某点是否在画布或其上的某个路径内
  bool isPointInsideCanvasPath(Offset globalPoint,
      {Path? path, double? extend}) {
    final RenderBox? renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // 将全局坐标转换为局部坐标
      final Offset canvasPosition = renderBox.globalToLocal(globalPoint);

      // 检查局部坐标是否在 RenderBox 的矩形内
      if (path != null) return path.contains(canvasPosition);
      final Rect localRect = Offset.zero & renderBox.size;
      return localRect.contains(canvasPosition);
    }
    // 如果 RenderBox 不存在
    return false;
  }

  Annotation? hitTest(Offset globalPosition) {
    // 对全部标注执行命中测试(使用逆序以保证后进者位于顶层)
    for (Annotation annotation in widget.annotationData.annotations.reversed) {
      if (isPointInsideCanvasPath(globalPosition, path: annotation.path)) {
        return annotation;
      }
    }
    return null;
  }

  // 处理单击事件
  void onTapUp(TapUpDetails details) {
    // 获取当前点击的标注(or null)
    final Annotation? annotation = hitTest(details.globalPosition);

    // 如果点击到了某个标注,那么选中它
    if (annotation != null) {
      widget.annotationData.selectAnnotation(annotation);
    } else {
      widget.annotationData.finishSelectingAnnotation();
    }
  }

  // 这是给onHover使用的回调，用于将清除当前Hover的标注的操作推迟到动画结束后执行
  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      widget.annotationData.hoverAnnotation(null);
    }
  }

  void onHover(PointerHoverEvent event) {
    if (widget.annotationData.selectedAnnotation != null) {
      final SystemMouseCursor cursor = editingHandlers.onHover(
          canvasPosition: globalToCanvas(event.position));
      if (cursor != currentCursor) {
        setState(() {
          currentCursor = cursor;
        });
      }
    } else {
      // 获取当前点击的标注(or null)
      final Annotation? annotation = hitTest(event.position);

      // 如果当前 hover 的 annotation 没有变化，直接返回
      if (annotation == widget.annotationData.hoveredAnnotation) return;

      // 如果有动画控制器
      if (widget.hoverAnimationController != null) {
        // 移除所有之前的监听器，避免冲突
        widget.hoverAnimationController!
            .removeStatusListener(_animationStatusListener);

        // 如果要清除 hoveredAnnotation（即设置为 null）
        if (annotation == null) {
          widget.hoverAnimationController!.reverse();
          widget.hoverAnimationController!
              .addStatusListener(_animationStatusListener);
        } else {
          // 如果有新的 annotation
          widget.hoverAnimationController!.forward();
          widget.annotationData.hoverAnnotation(annotation);
        }
      } else {
        // 如果没有动画控制器，直接更新
        widget.annotationData.hoverAnnotation(annotation);
      }
    }
  }

  void onHoverExit(PointerExitEvent event) {
    widget.annotationData.hoverAnnotation(null);
    editingHandlers.onHoverExit();
    if (currentCursor != SystemMouseCursors.basic) {
      setState(() {
        currentCursor = SystemMouseCursors.basic;
      });
    }
  }

  void onTorchScaleStart(ScaleStartDetails details) {
    if (details.pointerCount == 1) {
      // 如果触摸点不在当前选中标注的路径中或当前未在编辑中内则认为可以执行拖动
      Offset? canvasPosition = globalToCanvas(details.focalPoint);
      // // 如果正在新建标注
      // if (widget.annotationData.createdAnnotation != null) {
      //   scalingMode = ScaleType.annotation;
      //   editingHandlers.onPanStart(canvasPosition: canvasPosition);
      // // 如果既不是在新建也没有选中标注
      // } else
      if (widget.annotationData.selectedAnnotation == null &&
          widget.annotationData.createdAnnotation == null) {
        scalingMode = ScaleType.forward;
        // 否则，到这里就说明选中了标注，那么判断拖动开始位置是否在标注内
      } else if (editingHandlers.onPanStart(canvasPosition: canvasPosition)) {
        scalingMode = ScaleType.annotation;
      } else {
        scalingMode = ScaleType.forward;
      }
    }
    widget.onTorchScaleStart?.call(details);
  }

  void onTorchScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      // 拦截缩放行为
      // if (scalingMode != ScaleType.forward) return;
      // setState(() {
      //   canvasLeft += details.focalPointDelta.dx;
      //   canvasTop += details.focalPointDelta.dy;
      // });

      if (scalingMode == ScaleType.annotation) {
        editingHandlers.onPanUpdate(
            canvasPosition: globalToCanvas(details.focalPoint));
      } else {
        widget.onTorchScaleUpdate?.call(details);
      }
    } else {
      widget.onTorchScaleUpdate?.call(details);
    }
  }

  void onTorchScaleEnd(ScaleEndDetails details) {
    if (scalingMode == ScaleType.annotation) {
      editingHandlers.onPanEnd();
    }

    widget.onTorchScaleEnd?.call(details);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.annotationData == editingHandlers.annotationData) {
      editingHandlers.reloadAnnotationData(widget.annotationData);
    }
    return Stack(children: [
      MouseRegion(
        cursor: currentCursor,
        // cursor: SystemMouseCursors.wait,
        onHover: onHover,
        onExit: onHoverExit,
      ),
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        // 点击事件
        onTapUp: onTapUp,
        // 拖拽事件一并在此处理
        onScaleStart: onTorchScaleStart,
        onScaleUpdate: onTorchScaleUpdate,
        onScaleEnd: onTorchScaleEnd,
      ),
      Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (PointerSignalEvent details) {
          if (details is PointerScrollEvent) widget.onScroll?.call(details);
        },
      ),
    ]);
  }
}
