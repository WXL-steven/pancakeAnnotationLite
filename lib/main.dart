import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:pancake_annotation_lite/layout/editor/core.dart';
import 'package:pancake_annotation_lite/models/annotation.dart';
import 'package:pancake_annotation_lite/models/base.dart';
import 'package:pancake_annotation_lite/models/bbox.dart';

void main() {
  debugRepaintRainbowEnabled = true;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(appBar: null, body: AsyncLoader()),
    );
  }
}

class AsyncLoader extends StatefulWidget {
  const AsyncLoader({super.key});

  @override
  State<AsyncLoader> createState() => _AsyncLoaderState();
}

class _AsyncLoaderState extends State<AsyncLoader> {
  Future<AnnotationData>? _imageData;

  @override
  void initState() {
    super.initState();
    _imageData = _fetchAnnotationData();
  }

  Future<AnnotationData> _fetchAnnotationData() async {
    // 加载图像数据
    final ByteData data = await rootBundle.load('assets/images/640.png');
    // 转换为 Uint8List
    final Uint8List bytesImage = data.buffer.asUint8List();
    // 创建 Completer
    final Completer<AnnotationData> completer = Completer<AnnotationData>();

    // 解码图像
    ui.decodeImageFromList(bytesImage, (ui.Image img) {
      // 初始化 annotationData
      final annotationData = AnnotationData(
        annotations: [
          BBox.fromLTWH(
              category: Category(name: 'Test1', color: Colors.pinkAccent),
              left: 100,
              top: 100,
              width: 100,
              height: 100),
          BBox.fromLTWH(
              category: Category(name: 'Test2', color: Colors.purpleAccent),
              left: 250,
              top: 300,
              width: 150,
              height: 50),
        ],
        image: img,
      );

      // 完成 completer
      completer.complete(annotationData);
    });

    // 返回 future
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnnotationData>(
        future: _imageData,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else {
            // return ImageEditor(imageBytes: snapshot.data!);
            return Column(
              children: [
                Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        DevEditor1(
                          annotationData: snapshot.data!,
                        ),
                        const SizedBox(
                          width: 24,
                        ),
                        DevEditor2(
                          annotationData: snapshot.data!,
                        ),
                      ],
                    )
                    // child: ListenableBuilder(
                    //   listenable: snapshot.data!,
                    //   builder: (context, snapshot) {
                    //     return FilledButton(
                    //         onPressed: _annotationData.createdAnnotation == null
                    //             ? () {
                    //                 _annotationData.createAnnotation(
                    //                     BBox.fromLTWH(
                    //                         category: Category(
                    //                             name: 'Test2',
                    //                             color: Colors.purpleAccent),
                    //                         left: 0,
                    //                         top: 0,
                    //                         width: 0,
                    //                         height: 0));
                    //               }
                    //             : null,
                    //         child: const Text("Add BBox"));
                    //   },
                    // )
                    ),
                Expanded(
                  flex: 10,
                  child: AnnotationEditor(
                    annotationData: snapshot.data!,
                    // annotationData: AnnotationData(
                    //   annotations: [
                    //     BBox.fromLTWH(
                    //         category: Category(name: 'Test1', color: Colors.pinkAccent),
                    //         left: 100, top: 100, width: 100, height: 100),
                    //     BBox.fromLTWH(
                    //         category: Category(name: 'Test2', color: Colors.purpleAccent),
                    //         left: 250, top: 300, width: 150, height: 50),
                    //   ],
                    //   image: snapshot.data!
                    // )
                  ),
                )
              ],
            );
          }
        });
  }
}

class DevEditor1 extends StatelessWidget {
  final AnnotationData annotationData;

  const DevEditor1({
    super.key,
    required this.annotationData,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: annotationData,
      builder: (context, snapshot) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
                onPressed: annotationData.createdAnnotation == null
                    ? () {
                        annotationData.createAnnotation(BBox.fromLTWH(
                            category: Category(
                                name: 'Test2', color: Colors.purpleAccent),
                            left: 0,
                            top: 0,
                            width: 0,
                            height: 0));
                      }
                    : null,
                child: const Text("Add BBox: Test2")),
            const SizedBox(
              width: 24,
            ),
            FilledButton(
              onPressed: annotationData.selectedAnnotation == null
                  ? null
                  : () {
                      annotationData
                          .removeAnnotation(annotationData.selectedAnnotation!);
                    },
              child: const Text("Delete BBox"),
            )
          ],
        );
      },
    );
  }
}

class DevEditor2 extends StatelessWidget {
  final AnnotationData annotationData;

  const DevEditor2({
    super.key,
    required this.annotationData,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: annotationData.editHistory,
      builder: (context, snapshot) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
                onPressed: annotationData.editHistory.canRedo
                    ? () {
                        annotationData.redo();
                      }
                    : null,
                child: Text("Redo (${annotationData.editHistory.redoCount})")),
            const SizedBox(
              width: 24,
            ),
            FilledButton(
              onPressed: annotationData.editHistory.canUndo
                  ? () {
                      annotationData.undo();
                    }
                  : null,
              child: Text("Undo (${annotationData.editHistory.undoCount})"),
            )
          ],
        );
      },
    );
  }
}

class BBoxMetadata {
  final double x;
  final double y;
  final double width;
  final double height;
  final int? classId;
  final String? label;

  BBoxMetadata({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.classId,
    this.label,
  });

  Offset get topLeft {
    double x = this.x;
    double y = this.y;
    double width = this.width;
    double height = this.height;
    return Offset(x - width / 2, y - height / 2);
  }

  Offset get bottomRight {
    return Offset(x + width / 2, y + height / 2);
  }

  Map<String, double> get toXYXY {
    final topLeft = this.topLeft;
    final bottomRight = this.bottomRight;
    return {
      'x1': topLeft.dx,
      'y1': topLeft.dy,
      'x2': bottomRight.dx,
      'y2': bottomRight.dy,
    };
  }

  factory BBoxMetadata.fromXYXY({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    int? classId,
    String? label,
  }) {
    final minX = x1 < x2 ? x1 : x2;
    final maxX = x1 > x2 ? x1 : x2;
    final minY = y1 < y2 ? y1 : y2;
    final maxY = y1 > y2 ? y1 : y2;

    final width = maxX - minX;
    final height = maxY - minY;
    final centerX = minX + width / 2;
    final centerY = minY + height / 2;

    return BBoxMetadata(
      x: centerX,
      y: centerY,
      width: width,
      height: height,
      classId: classId,
      label: label,
    );
  }
}

class BBoxLayout extends StatefulWidget {
  final BBoxMetadata metadata;
  final Color color;
  final double strokeWidth;
  final bool hitTestable;

  const BBoxLayout({
    super.key,
    required this.metadata,
    this.color = Colors.red,
    this.strokeWidth = 2.0,
    this.hitTestable = true,
  });

  @override
  State<BBoxLayout> createState() => _BBoxLayoutState();
}

class _BBoxLayoutState extends State<BBoxLayout> {
  BBoxMetadata get metadata => widget.metadata;

  Color get color => widget.color;

  double get strokeWidth => widget.strokeWidth;

  // 增加一个状态变量来控制线条的粗细
  double _lineWidth = 0.0;

  @override
  void initState() {
    super.initState();
    _lineWidth = strokeWidth;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: metadata.topLeft.dx - _lineWidth,
      top: metadata.topLeft.dy - _lineWidth,
      child: widget.hitTestable
          ? MouseRegion(
              onEnter: (_) {
                setState(() {
                  _lineWidth = strokeWidth * 1.5;
                });
              },
              onExit: (_) {
                setState(() {
                  _lineWidth = strokeWidth;
                });
              },
              child: SizedBox(
                width: metadata.width.abs() + _lineWidth * 2,
                height: metadata.height.abs() + _lineWidth * 2,
                child: Container(
                  width: metadata.width.abs() + _lineWidth * 2,
                  height: metadata.height.abs() + _lineWidth * 2,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: color,
                      width: _lineWidth,
                    ),
                  ),
                ),
              ),
            )
          : IgnorePointer(
              child: SizedBox(
                width: metadata.width.abs() + _lineWidth * 2,
                height: metadata.height.abs() + _lineWidth * 2,
                child: Container(
                  width: metadata.width.abs() + _lineWidth * 2,
                  height: metadata.height.abs() + _lineWidth * 2,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: color,
                      width: _lineWidth,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class ImageEditor extends StatefulWidget {
  final Uint8List imageBytes;
  final List<BBoxMetadata> bboxes;

  const ImageEditor({
    super.key,
    required this.imageBytes,
    this.bboxes = const [],
  });

  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  double x = 100.0;
  double y = 100.0;
  double scale = 1.0;
  double imgWidth = 320.0;
  double imgHeight = 320.0;
  double canvasWidth = 1280.0;
  double canvasHeight = 720.0;

  double _x1 = 0.0;
  double _y1 = 0.0;
  double _x2 = 0.0;
  double _y2 = 0.0;

  List<BBoxMetadata> bboxes = [
    BBoxMetadata(
        x: 100, y: 100, width: 50, height: 150, classId: 0, label: 'cat'),
  ];

  bool isDrawing = false;
  BBoxMetadata? draggingBBox;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      imgWidth =
          _imageKey.currentContext!.findRenderObject()!.paintBounds.size.width;
      imgHeight =
          _imageKey.currentContext!.findRenderObject()!.paintBounds.size.height;
      _resetCanvas();
    });
  }

  Future<void> _resetCanvas() async {
    await Future.delayed(const Duration(milliseconds: 100));
    // 重新查询
    final Size canvasSize =
        _canvasKey.currentContext!.findRenderObject()!.paintBounds.size;
    final double newCanvasWidth = canvasSize.width;
    final double newCanvasHeight = canvasSize.height;
    final double newImgWidth =
        _imageKey.currentContext!.findRenderObject()!.paintBounds.size.width;
    final double newImgHeight =
        _imageKey.currentContext!.findRenderObject()!.paintBounds.size.height;
    if (newCanvasWidth == canvasWidth &&
        newCanvasHeight == canvasHeight &&
        newImgWidth == imgWidth &&
        newImgHeight == imgHeight) {
      return;
    }

    canvasWidth = newCanvasWidth;
    canvasHeight = newCanvasHeight;
    imgWidth = newImgWidth;
    imgHeight = newImgHeight;
    setState(() {
      // 计算图像居中位置
      x = (canvasWidth - imgWidth) / 2;
      y = (canvasHeight - imgHeight) / 2;

      // 计算初始缩放
      if (imgWidth > imgHeight || imgWidth == imgHeight) {
        final scaleX = canvasWidth * 0.8 / imgWidth;
        final scaleY = canvasHeight * 0.8 / imgHeight;
        scale = scaleX < scaleY ? scaleX : scaleY;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (pointerSignal) {
        // 💩
        if (pointerSignal is PointerScrollEvent) {
          // 计算缩放中心
          final double centerX = x + imgWidth / 2;
          final double centerY = y + imgHeight / 2;

          // 计算鼠标相对缩放中心的差值
          final double dx = pointerSignal.position.dx - centerX;
          final double dy = pointerSignal.position.dy - centerY;

          // 更新缩放比例
          double newScale =
              scale * (pointerSignal.scrollDelta.dy > 0 ? 0.9 : 1.1);
          newScale = newScale.clamp(0.1, 5.0);

          // 计算补偿量
          final double offsetX = dx * (1 - newScale / scale);
          final double offsetY = dy * (1 - newScale / scale);

          setState(() {
            scale = newScale;
            x += offsetX;
            y += offsetY;
          });
        }
      },
      child: Stack(
        key: _canvasKey,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  x += details.delta.dx;
                  y += details.delta.dy;
                });
              },
            ),
          ),
          Positioned(
            left: x,
            top: y,
            child: Transform.scale(
              scale: scale,
              child: Stack(
                children: [
                  GestureDetector(
                    onPanStart: (details) {
                      if (isDrawing) {
                        setState(() {
                          _x1 = details.localPosition.dx;
                          _y1 = details.localPosition.dy;
                          _x2 = details.localPosition.dx;
                          _y2 = details.localPosition.dy;
                          draggingBBox = BBoxMetadata.fromXYXY(
                            x1: _x1,
                            y1: _y1,
                            x2: _x2,
                            y2: _y2,
                          );
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      if (isDrawing) {
                        setState(() {
                          _x2 = details.localPosition.dx;
                          _y2 = details.localPosition.dy;
                          draggingBBox = BBoxMetadata.fromXYXY(
                            x1: _x1,
                            y1: _y1,
                            x2: _x2,
                            y2: _y2,
                          );
                        });
                      } else {
                        setState(() {
                          x += details.delta.dx * scale;
                          y += details.delta.dy * scale;
                        });
                      }
                    },
                    child: Image.memory(widget.imageBytes,
                        key: _imageKey, fit: BoxFit.fill),
                  ),
                  for (var bbox in bboxes) BBoxLayout(metadata: bbox),
                  if (isDrawing && draggingBBox != null)
                    BBoxLayout(
                      metadata: draggingBBox!,
                      color: Colors.blue,
                      hitTestable: false,
                    ),
                ],
              ),
              //Image.asset('assets/images/640.png'),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, scale: ${scale.toStringAsFixed(2)}'),
                  Checkbox(
                    value: isDrawing,
                    onChanged: (value) {
                      setState(() {
                        isDrawing = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
