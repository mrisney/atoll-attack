import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'island_game.dart';
import '../models/unit_model.dart';

class ArrowComponent extends PositionComponent with HasGameRef<IslandGame> {
  final Vector2 startPosition;
  final Vector2 targetPosition;
  final Team team;
  
  // Arrow animation properties
  double _progress = 0.0;
  final double _speed = 150.0; // pixels per second
  final double _maxHeight = 30.0; // maximum height of arc
  bool _isActive = true;
  
  ArrowComponent({
    required this.startPosition,
    required this.targetPosition,
    required this.team,
  }) : super(
    position: startPosition.clone(),
    size: Vector2(4, 12),
    anchor: Anchor.center,
  );
  
  @override
  void render(Canvas canvas) {
    if (!_isActive) return;
    
    // Draw the arrow
    final Paint arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Calculate arrow direction
    final Vector2 direction = (targetPosition - startPosition).normalized();
    final double angle = math.atan2(direction.y, direction.x);
    
    // Save canvas state
    canvas.save();
    
    // Translate and rotate canvas to arrow position and direction
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(angle);
    
    // Draw arrow line
    canvas.drawLine(
      Offset(-size.x / 2, 0),
      Offset(size.x / 2, 0),
      arrowPaint,
    );
    
    // Draw arrow head
    final Path arrowHead = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x / 2 - 3, -2)
      ..lineTo(size.x / 2 - 3, 2)
      ..close();
    
    canvas.drawPath(arrowHead, Paint()..color = Colors.white);
    
    // Restore canvas state
    canvas.restore();
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    
    if (!_isActive) return;
    
    // Update progress
    _progress += dt * (_speed / startPosition.distanceTo(targetPosition));
    if (_progress >= 1.0) {
      _isActive = false;
      removeFromParent();
      return;
    }
    
    // Calculate position along arc
    final Vector2 direct = targetPosition - startPosition;
    final Vector2 currentPos = startPosition + direct * _progress;
    
    // Add arc height using sine wave
    final double arcHeight = math.sin(_progress * math.pi) * _maxHeight;
    final Vector2 perpendicular = Vector2(-direct.y, direct.x).normalized();
    currentPos.add(perpendicular * arcHeight);
    
    // Update component position
    position.setFrom(currentPos);
  }
}