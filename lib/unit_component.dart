import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class UnitComponent extends PositionComponent {
  final Color color;
  final double radius;

  UnitComponent(
      {required Vector2 position, this.color = Colors.orange, this.radius = 7})
      : super(
          position: position,
          size: Vector2.all(2 * radius),
          anchor: Anchor.center,
        );

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    // Optional: add a border
    canvas.drawCircle(
        Offset(radius, radius),
        radius,
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  void update(double dt) {
    // For now, does not move; add movement/pathfinding here if desired.
  }
}
