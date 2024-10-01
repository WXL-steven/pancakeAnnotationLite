import 'package:flutter/material.dart';

abstract class Annotation {
  // 基础标注类，可以扩展以支持不同类型的标注

  Path get path;

  List<Offset> get nodes;

  List<List<Offset>> get lines;

  Category get category;

  bool get valid;
}

class Category {
  final String name;
  final Color color;

  Category({
    required this.name,
    this.color = Colors.blueAccent,
  });

  @override
  String toString() {
    return 'Category(name: $name, color: $color)';
  }
}
