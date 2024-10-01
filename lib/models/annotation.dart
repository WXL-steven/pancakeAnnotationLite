import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:pancake_annotation_lite/models/base.dart';

class EditStep {
  final Annotation? previous;
  final Annotation? current;
  EditStep({this.previous, this.current});
}

class EditHistory with ChangeNotifier {
  final List<EditStep> _steps = [];
  int _currentStepIndex = 0;

  Annotation? _snapshot;
  bool _onSnapshot = false;

  bool get canUndo => _currentStepIndex > 0;
  int get undoCount => _currentStepIndex;
  bool get canRedo => _currentStepIndex < _steps.length;
  int get redoCount => _steps.length - _currentStepIndex;

  void clear() {
    _steps.clear();
    _currentStepIndex = 0;
    notifyListeners();
  }

  EditStep? undo() {
    if (!canUndo) return null;
    _currentStepIndex -= 1;
    notifyListeners();
    debugPrint("Undo to step: $_currentStepIndex");
    return _steps[_currentStepIndex];
  }

  EditStep? redo() {
    if (!canRedo) return null;
    _currentStepIndex += 1;
    notifyListeners();
    debugPrint("Redo to step: $_currentStepIndex of ${_steps.length}");
    return _steps[_currentStepIndex - 1];
  }

  void addStep(EditStep step) {
    // 如果未修改,则直接返回
    if (step.previous == step.current) return;
    // 如果还有redo的步骤,则先清除,避免因为冲突导致无法正常redo
    if (_currentStepIndex < _steps.length) {
      _steps.removeRange(_currentStepIndex, _steps.length);
    }
    // _steps.insert(_currentStepIndex + 1, step);
    _steps.add(step);
    _currentStepIndex++;
    // 似乎应该是把这个Bug修复了
    // // 检查一下是否对齐
    // if (_currentStepIndex != _steps.length) {
    //   throw Exception("Internal error, step history is not aligned: "
    //       "_currentStepIndex != _steps.length "
    //       "($_currentStepIndex != ${_steps.length})");
    // }
    notifyListeners();
  }

  void newSnapshot(Annotation? previous) {
    _snapshot = previous;
    _onSnapshot = true;
  }

  void finishSnapshot(Annotation? current) {
    if (!_onSnapshot) return;
    addStep(EditStep(previous: _snapshot, current: current));
    _onSnapshot = false;
  }
}

class AnnotationData with ChangeNotifier {
  final List<Annotation> _annotations = [];
  Annotation? _selectedAnnotation;
  Annotation? _hoveredAnnotation;
  Annotation? _createdAnnotation;
  final ui.Image image;
  final EditHistory editHistory = EditHistory();
  late int imageWidth;
  late int imageHeight;

  AnnotationData({
    required this.image,
    List<Annotation>? annotations,
  }) {
    _annotations.addAll(annotations ?? []);
    imageWidth = image.width;
    imageHeight = image.height;
  }

  List<Annotation> get annotations => List.unmodifiable(_annotations);

  Annotation? get createdAnnotation => _createdAnnotation;

  Annotation? get selectedAnnotation => _selectedAnnotation;

  Annotation? get hoveredAnnotation => _hoveredAnnotation;

  // WARN: 已弃用此setter，请使用更明确的方法执行创建、更新和完成操作
  // set selectedAnnotation(Annotation? annotation) {
  //   if (identical(annotation, _selectedAnnotation)) return;
  //   _selectedAnnotation = annotation;
  //   notifyListeners();
  // }

  // WARN: 已弃用此setter，请使用更明确的方法执行更新操作
  // set hoveredAnnotation(Annotation? annotation) {
  //   if (identical(annotation, _hoveredAnnotation)) return;
  //   _hoveredAnnotation = annotation;
  //   notifyListeners();
  // }

  // WARN: 已弃用此setter，请使用更明确的方法执行创建、更新和完成操作
  // set createdAnnotation(Annotation? annotation) {
  //   if (annotation == null) {
  //     if (_createdAnnotation == null) return;
  //     finishCreatingAnnotation();
  //     return;
  //   } else {
  //     if (identical(annotation, _createdAnnotation)) return;
  //     if (_selectedAnnotation != null) selectedAnnotation = null;
  //     _createdAnnotation = annotation;
  //     notifyListeners();
  //   }
  // }

  /*
  * 创建标注函数区域开始
  * Start of create annotation functions
  * */

  // 创建新的标注时，通过此函数传入一个标注实例，用于确定标注类型与类别
  void createAnnotation(Annotation annotation, {bool silent = false}) {
    // 如果存在选中的标注，则先取消选中
    if (_selectedAnnotation != null) finishSelectingAnnotation(silent: true);
    // 清空悬停的标注
    if (_hoveredAnnotation != null) hoverAnnotation(null, silent: true);

    if (annotation == _createdAnnotation) return;

    _createdAnnotation = annotation;

    // 启动快照以记录变更
    editHistory.newSnapshot(null);

    if (silent) return;
    notifyListeners();
  }

  // 通过此函数来更新创建中的标注
  void updateCreatingAnnotation(Annotation annotation, {bool silent = false}) {
    // 如果没有创建中的标注，则直接返回
    if (_createdAnnotation == null) return;

    // 如果标注类型不匹配则抛出异常，引导开发者避免在创建过程中修改标注类型
    if (_createdAnnotation!.runtimeType != annotation.runtimeType) {
      throw Exception("Annotation type mismatch. "
          "Currently created annotation is ${_createdAnnotation!.runtimeType}, "
          "but new annotation is ${annotation.runtimeType}. \n"
          "Please avoid changing the annotation type during creation. "
          "Recommend to modify the annotation type during editing(selecting).");
    }

    _createdAnnotation = annotation;

    if (silent) return;
    notifyListeners();
  }

  // 通过此函数来完成创建过程，如果存在创建中的标注，将此标注转换为选中的标注
  void finishCreatingAnnotation({bool silent = false}) {
    if (_createdAnnotation == null) return;
    // 检查一下创建的对象是否合法
    if (_createdAnnotation!.valid) {
      // 因为`selectAnnotation`会检查是否在创建过程中,故在此先复制一份并清空
      // `_selectedAnnotation`的值
      final annotation = _createdAnnotation!;
      _createdAnnotation = null;

      // 完成快照
      editHistory.finishSnapshot(annotation);

      // 选中对象
      selectAnnotation(annotation, silent: true);
    }

    if (silent) return;
    notifyListeners();
  }

  /*
  * 创建标注函数区域结束
  * End of create annotation functions
  * */

  /*
  * 选择/编辑标注函数区域开始(其实这两个是一样的)
  * Start of edit annotation functions(actually they are the same)
  * */

  // 选择标注(可能要进入编辑了)
  void selectAnnotation(Annotation annotation, {bool silent = false}) {
    if (_selectedAnnotation == annotation) return;

    // 首先判断一下是否有编辑中的,如果有就可以忽略选择了
    if (_createdAnnotation != null) return;
    // 清空悬停的标注
    if (_hoveredAnnotation != null) hoverAnnotation(null, silent: true);

    // 新的选择行为决定从原始列表中剔除选中的,单独保存在`_selectedAnnotation`中
    // 当然如果原始列表里没有我们也如愿让他成为选中的,只不过剔除过程就略过了
    if (_annotations.contains(annotation)) {
      _annotations.remove(annotation);
    }

    // 顺便判断一下现在选中的是不是空,如果不是给它取消选中了
    // (声明silent = true来避免重复通知,因为当前函数还要调用notifyListeners)
    if (_selectedAnnotation != null) finishSelectingAnnotation(silent: true);

    // 最后把新的标注选中
    _selectedAnnotation = annotation;

    // 拍摄快照
    editHistory.newSnapshot(annotation);

    if (silent) return;
    notifyListeners();
  }

  // 通过此函数来更新选中的标注
  void updateSelectingAnnotation(Annotation annotation, {bool silent = false}) {
    if (_selectedAnnotation == annotation) return;

    _selectedAnnotation = annotation;

    if (silent) return;
    notifyListeners();
  }

  void snapshotSelectingAnnotation() {
    if (_selectedAnnotation == null) return;

    // 完成快照
    editHistory.finishSnapshot(_selectedAnnotation!);

    // 新建快照
    editHistory.newSnapshot(_selectedAnnotation!);
  }

  // 通过此函数来完成选中过程
  void finishSelectingAnnotation({bool silent = false}) {
    if (_selectedAnnotation == null) return;

    // 因为新的行为把原始列表里的标注剔除了，所以这里要重新添加进去
    // 当然前提是先判断一下现在的是否合法
    if (_selectedAnnotation!.valid) {
      _annotations.add(_selectedAnnotation!);

      // 完成快照
      editHistory.finishSnapshot(_selectedAnnotation!);
    }

    _selectedAnnotation = null;

    if (silent) return;
    notifyListeners();
  }

  /*
  * 选择/编辑标注函数区域结束
  * End of edit annotation functions
  * */

  /*
  * 悬停标注函数区域开始
  * Start of hover annotation functions
  *
  * Steven: 说实话我觉得因为这个悬停的变换可能调用/变换很频繁,我觉得没必要每次悬停都从原始
  *         List中把悬停的标注剔除掉,所以在绘制的时候检查一下当前绘制的标注是否被悬停就好了
  * */

  void hoverAnnotation(Annotation? annotation, {bool silent = false}) {
    if (annotation == _hoveredAnnotation) return;

    // 如果传入的对象是空，则清空悬停中的标注
    if (annotation == null) {
      _hoveredAnnotation = null;
      return;
    }

    // 因为悬停对象不是独立存储,所以判断一下传入对象是否是List中的对象
    if (!_annotations.contains(annotation)) return;

    // 判断一下如果有创建中和编辑中的标注，则清空悬停中的标注并返回
    if (_createdAnnotation != null) {
      _hoveredAnnotation = null;
      return;
    }

    _hoveredAnnotation = annotation;
    if (silent) return;
    notifyListeners();
  }

  /*
  * 悬停标注函数区域结束
  * End of hover annotation functions
  * */

  // WARN: 此函数已被弃用,请使用指代更为明确的`finishSelectingAnnotation`函数
  // void finishSelectingAnnotation() {
  //   if (_selectedAnnotation == null) return;
  //   _selectedAnnotation = null;
  //   notifyListeners();
  // }

  // WARN: 此函数已被弃用,请使用指代更为明确的`finishSelectingAnnotation`函数
  // void finishEditingAnnotation() {
  //   if (_selectedAnnotation == null) return;
  //   _selectedAnnotation = null;
  //   notifyListeners();
  // }

  void addAnnotation(Annotation annotation) {
    _annotations.add(annotation);
    // 添加快照
    editHistory.addStep(EditStep(previous: null, current: annotation));
    notifyListeners();
  }

  void removeAnnotation(Annotation annotation) {
    _annotations.remove(annotation);
    if (_selectedAnnotation == annotation) _selectedAnnotation = null;
    if (_hoveredAnnotation == annotation) _hoveredAnnotation = null;
    // 添加快照
    editHistory.addStep(EditStep(previous: annotation, current: null));
    notifyListeners();
  }

  void updateAnnotation(
      {required Annotation oldAnnotation, required Annotation newAnnotation}) {
    if (!_annotations.contains(oldAnnotation)) return;
    _annotations.remove(oldAnnotation);
    _annotations.add(newAnnotation);
    if (_hoveredAnnotation == oldAnnotation) _hoveredAnnotation = newAnnotation;
    // 添加快照
    editHistory
        .addStep(EditStep(previous: oldAnnotation, current: newAnnotation));
    notifyListeners();
  }

  bool undo({bool force = false}) {
    if (!editHistory.canUndo) return false;
    final step = editHistory.undo();
    if (step == null) return false;

    // 首先取消正在创建和选择的任务
    finishCreatingAnnotation(silent: true);
    finishSelectingAnnotation(silent: true);

    // 如果快照的当前状态不是空,即说明快照非删除操作
    if (step.current != null) {
      // 查找当前List中是否存在快照中的当前状态
      if (_annotations.contains(step.current!)) {
        if (step.previous != null) {
          // 如果存在，则把当前状态替换成快照中的旧状态
          _annotations[_annotations.indexOf(step.current!)] = step.previous!;
        } else {
          // 如果旧状态是空,那么这个快照是创建操作，删除当前状态
          _annotations.remove(step.current!);
        }
      } else if (force) {
        // 如果不存在,但是指定强制操作,则直接添加快照的旧状态(如果是空就只能跳过了)
        if (step.previous != null) _annotations.add(step.previous!);
      } else {
        // 否则我们认为该回退操作无法完成,虽然理论上我们应当避免这种情况
        debugPrint("Warning: Failed to undo step");
        return false;
      }
    } else {
      // 反之我们就假定快照是删除操作,添加旧状态即可
      if (step.previous != null) _annotations.add(step.previous!);
    }

    // // 如果操作成功,那么应当把此次操作添加到快照中
    // editHistory.addStep(step);
    notifyListeners();
    return true;
  }

  bool redo({bool force = false}) {
    if (!editHistory.canRedo) return false;
    final step = editHistory.redo();
    if (step == null) return false;

    // 首先取消正在创建和选择的任务
    finishCreatingAnnotation(silent: true);
    finishSelectingAnnotation(silent: true);

    // 如果快照的旧状态不是空,即说明快照非创建操作
    if (step.previous != null) {
      // 查找当前List中是否存在快照中的旧状态
      if (_annotations.contains(step.previous!)) {
        // 如果存在,则把旧状态替换成快照中的新状态
        if (step.current != null) {
          _annotations[_annotations.indexOf(step.previous!)] = step.current!;
        } else {
          // 如果新状态是空,那么这是一个删除操作,则直接删除旧状态
          _annotations.remove(step.previous!);
        }
      } else if (force) {
        // 如果不存在,但是指定强制操作,则直接添加快照的新状态(如果是空就跳过)
        if (step.current != null) _annotations.add(step.current!);
      } else {
        debugPrint("Warning: Failed to redo step");
        return false;
      }
    } else {
      // 反之我们就假定快照是创建操作,添加新状态即可
      if (step.current != null) _annotations.add(step.current!);
    }

    // // 如果操作成功,那么应当把此次操作添加到快照中
    // editHistory.addStep(step);
    notifyListeners();
    return true;
  }
}
