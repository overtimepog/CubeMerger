import 'package:flutter/material.dart';

class Cube {
  final int? value;
  final bool isObstacle;
  final bool isMoving;
  final bool isMerging;
  final bool isNew;
  final bool isOutOfShape;
  final Offset position;
  final Offset startPosition;
  final Offset endPosition;
  final double scale;
  final double rotation;

  const Cube({
    this.value,
    this.isObstacle = false,
    this.isMoving = false,
    this.isMerging = false,
    this.isNew = false,
    this.isOutOfShape = false,
    this.position = Offset.zero,
    this.startPosition = Offset.zero,
    this.endPosition = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Cube copyWith({
    int? value,
    bool? isObstacle,
    bool? isMoving,
    bool? isMerging,
    bool? isNew,
    bool? isOutOfShape,
    Offset? position,
    Offset? startPosition,
    Offset? endPosition,
    double? scale,
    double? rotation,
  }) {
    return Cube(
      value: value ?? this.value,
      isObstacle: isObstacle ?? this.isObstacle,
      isMoving: isMoving ?? this.isMoving,
      isMerging: isMerging ?? this.isMerging,
      isNew: isNew ?? this.isNew,
      isOutOfShape: isOutOfShape ?? this.isOutOfShape,
      position: position ?? this.position,
      startPosition: startPosition ?? this.startPosition,
      endPosition: endPosition ?? this.endPosition,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Color getColor() {
    if (isOutOfShape) return Colors.transparent;
    if (isObstacle) return Colors.black87;
    if (value == null) return Colors.grey[300]!;

    final hue = (value!.toDouble() * 25) % 360;
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor();
  }

  bool get isEmpty => value == null && !isObstacle && !isOutOfShape;
  bool get canMerge => value != null && !isObstacle && !isOutOfShape;
}
