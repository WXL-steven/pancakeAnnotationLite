import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:pancake_annotation_lite/models/annotation.dart';
import 'package:pancake_annotation_lite/layout/editor/interaction_layer.dart';
import 'package:pancake_annotation_lite/layout/editor/canvas.dart';

class AnnotationEditor extends StatefulWidget {
  final AnnotationData annotationData;

  const AnnotationEditor({
    super.key,
    required this.annotationData,
  });

  @override
  State<AnnotationEditor> createState() => _AnnotationEditorState();
}

class _AnnotationEditorState extends State<AnnotationEditor>
    with TickerProviderStateMixin {
  GlobalKey rootLayoutKey = GlobalKey();
  GlobalKey canvasKey = GlobalKey();
  GlobalKey interactionKey = GlobalKey();
  late AnimationController hoverAnimationController;
  late Animation<double> hoverAnimation;

  double scale = 1;
  Offset scaleAt = Offset.zero;
  double scaleFrom = 1;
  double canvasLeft = 0;
  double canvasTop = 0;

  late int imageWidth;
  late int imageHeight;

  Size lastLayoutSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // _loadImage();
    imageWidth = widget.annotationData.imageWidth;
    imageHeight = widget.annotationData.imageHeight;

    hoverAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    hoverAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(hoverAnimationController);
  }

  void clampCanvasPosition() {
    final RenderBox? canvasRenderBox =
        canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? rootRenderBox =
        rootLayoutKey.currentContext?.findRenderObject() as RenderBox?;

    if (canvasRenderBox == null || rootRenderBox == null) return;

    final Size rootSize = rootRenderBox.size;
    final Size canvasSize = canvasRenderBox.size;

    final Offset canvasLeftTop =
        canvasRenderBox.localToGlobal(Offset.zero, ancestor: rootRenderBox);
    final Offset canvasRightBottom = canvasRenderBox.localToGlobal(
        canvasSize.bottomRight(Offset.zero),
        ancestor: rootRenderBox);
    final Offset canvasRealSize = canvasRightBottom - canvasLeftTop;

    // 计算较小尺寸的 20% 边距
    final double horizontalMargin = 0.2 *
        (rootSize.width < canvasRealSize.dx
            ? rootSize.width
            : canvasRealSize.dx);
    final double verticalMargin = 0.2 *
        (rootSize.height < canvasRealSize.dy
            ? rootSize.height
            : canvasRealSize.dy);

    // 计算新的 canvasLeft 和 canvasTop，确保在边界内
    double newCanvasLeft = canvasLeft;
    double newCanvasTop = canvasTop;

    if (canvasRightBottom.dx < horizontalMargin) {
      newCanvasLeft += horizontalMargin - canvasRightBottom.dx;
    } else if (canvasLeftTop.dx > rootSize.width - horizontalMargin) {
      newCanvasLeft -= canvasLeftTop.dx - (rootSize.width - horizontalMargin);
    }

    if (canvasRightBottom.dy < verticalMargin) {
      newCanvasTop += verticalMargin - canvasRightBottom.dy;
    } else if (canvasLeftTop.dy > rootSize.height - verticalMargin) {
      newCanvasTop -= canvasLeftTop.dy - (rootSize.height - verticalMargin);
    }

    // 更新 canvasLeft 和 canvasTop
    canvasLeft = newCanvasLeft;
    canvasTop = newCanvasTop;
  }

  void smoothScale(PointerScrollEvent details) {
    if (details.scrollDelta.dy == 0) return;

    final newScale =
        (scale * (details.scrollDelta.dy > 0 ? 0.9 : 1.1)).clamp(0.1, 5.0);

    // 以下代码用于重新定位图像使得指针中心的相对位置不变
    // 获取画布的尺寸
    final int canvasWidth = imageWidth;
    final int canvasHeight = imageHeight;

    // 求缩放中心
    final double centerX = canvasLeft + canvasWidth / 2;
    final double centerY = canvasTop + canvasHeight / 2;

    // 计算鼠标相对缩放中心的差值
    // 由于Listener获取到的是相对于界面的坐标，因此需要转换为相对于Widget的坐标
    final RenderBox renderBox1 =
        interactionKey.currentContext!.findRenderObject() as RenderBox;
    final listenerOffset = renderBox1.localToGlobal(Offset.zero);
    final pointerX = details.position.dx;
    final pointerY = details.position.dy;
    final dx = pointerX - listenerOffset.dx - centerX;
    final dy = pointerY - listenerOffset.dy - centerY;

    // 计算补偿量
    final double offsetX = dx * (1 - newScale / scale);
    final double offsetY = dy * (1 - newScale / scale);

    setState(() {
      scale = newScale;
      canvasLeft += offsetX;
      canvasTop += offsetY;
    });
  }

  bool isPointInsideCanvasPath(Offset globalPoint,
      {Path? path, double? extend}) {
    final RenderBox? renderBox =
        canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // 将全局坐标转换为局部坐标
      final Offset localPoint = renderBox.globalToLocal(globalPoint);

      // 检查局部坐标是否在 RenderBox 的矩形内
      if (path != null) return path.contains(localPoint);
      final Rect localRect = Offset.zero & renderBox.size;
      return localRect.contains(localPoint);
    }
    // 如果 RenderBox 不存在
    return false;
  }

  void onTorchScaleStart(ScaleStartDetails details) {
    if (details.pointerCount > 1) {
      scaleFrom = scale;

      // 计算 RenderBox 的中心点全局坐标
      final boxCenter =
          Offset(canvasLeft + imageWidth / 2, canvasTop + imageHeight / 2);
      // 计算相对位置
      scaleAt = details.localFocalPoint - boxCenter;
    }
  }

  void onTorchScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      setState(() {
        canvasLeft += details.focalPointDelta.dx;
        canvasTop += details.focalPointDelta.dy;
      });
    } else if (details.pointerCount > 1) {
      // 计算新的缩放比例
      final newScale = (scaleFrom * details.scale).clamp(0.1, 5.0);

      // 计算缩放中心的偏移量
      final double offsetX =
          scaleAt.dx * (1 - newScale / scale) + details.focalPointDelta.dx;
      final double offsetY =
          scaleAt.dy * (1 - newScale / scale) + details.focalPointDelta.dy;

      setState(() {
        scale = newScale;
        canvasLeft += offsetX;
        canvasTop += offsetY;
      });
    }
  }

  void onTorchScaleEnd(ScaleEndDetails details) {
    setState(() {
      clampCanvasPosition();
    });
  }

  void resetCanvasPosition() {
    // 在帧结束后执行布局检查和更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 获取RootLayoutKey对应的Widget
      final RenderBox? renderBox =
          interactionKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      Size currentSize = renderBox.size;
      // 判断窗口布局是否发生变化
      if (lastLayoutSize == currentSize || currentSize == Size.zero) {
        return;
      }

      lastLayoutSize = currentSize;

      // 计算图像居中位置
      final double newCanvasLeft = currentSize.width / 2 - imageWidth / 2;
      final double newCanvasTop = currentSize.height / 2 - imageHeight / 2;
      debugPrint(
          "Current Size: $currentSize, New Canvas Left: $newCanvasLeft, New Canvas Top: $newCanvasTop");

      // 计算初始缩放(80%)
      final double scaleX = currentSize.width * 0.8 / imageWidth;
      final double scaleY = currentSize.height * 0.8 / imageHeight;
      final double newScale = scaleX < scaleY ? scaleX : scaleY;

      // 更新状态
      setState(() {
        canvasLeft = newCanvasLeft;
        canvasTop = newCanvasTop;
        scale = newScale;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前窗口大小
    MediaQuery.of(context).size;
    resetCanvasPosition();

    return Stack(
      key: rootLayoutKey,
      // 开发笔记：构想的绘制层次(由后向前)
      // 1. 图像背景
      // 2. 点击/触摸事件控制(鼠标/触控的缩放/拖动)(最下层)
      // 3. 覆盖图像的点击/触摸事件控制
      // 4. 已存在的BBox的绘制
      // 5. BBox的选择触摸事件控制
      children: [
        // 图像背景
        // 平移
        Positioned(
          left: canvasLeft,
          top: canvasTop,
          // 缩放
          child: Transform.scale(
            scale: scale,
            // 限制画布大小
            child: SizedBox(
                width: imageWidth.toDouble(),
                height: imageHeight.toDouble(),
                // 悬停动画
                child: AnimatedBuilder(
                    animation: hoverAnimationController,
                    builder: (context, child) {
                      return AnnotationCanvas(
                        key: canvasKey,
                        annotationData: widget.annotationData,
                        hoverAnimationValue: hoverAnimationController.value,
                      );
                    })),
          ),
        ),

        // 交互控制器
        AnnotationInteractionLayer(
          key: interactionKey,
          canvasKey: canvasKey,
          annotationData: widget.annotationData,
          onScroll: smoothScale,
          onTorchScaleStart: onTorchScaleStart,
          onTorchScaleUpdate: onTorchScaleUpdate,
          onTorchScaleEnd: onTorchScaleEnd,
          hoverAnimationController: hoverAnimationController,
        ),
      ],
    );
  }
}
