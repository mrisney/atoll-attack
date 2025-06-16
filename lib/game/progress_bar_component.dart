import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';

class ProgressBarComponent extends PositionComponent {
  final UnitModel unit;
  final Color barColor;
  final String label;
  double progress; // 0.0 to 1.0
  
  // Visual properties
  final double _barWidth = 30.0;
  final double _barHeight = 4.0;
  final double _verticalOffset; // Distance above the unit
  
  ProgressBarComponent({
    required this.unit,
    required this.barColor,
    required this.label,
    required this.progress,
    double verticalOffset = 15.0,
  }) : _verticalOffset = verticalOffset,
       super(
         position: unit.position.clone(),
         size: Vector2(40, 20), // Size to contain progress bar and text
         anchor: Anchor.center,
       );
  
  @override
  void update(double dt) {
    super.update(dt);
    
    // Update position to follow unit
    position.setFrom(unit.position);
  }
  
  /// Update the progress value
  void updateProgress(double newProgress) {
    progress = newProgress.clamp(0.0, 1.0);
  }
  
  @override
  void render(Canvas canvas) {
    // Only render if unit is alive
    if (unit.health <= 0) return;
    
    // Progress bar position (above the unit)
    double barX = size.x / 2 - _barWidth / 2;
    double barY = size.y / 2 - _verticalOffset;
    
    // Background bar
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _barWidth, _barHeight),
        Radius.circular(_barHeight / 2),
      ),
      backgroundPaint,
    );
    
    // Progress fill
    final Paint progressPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _barWidth * progress, _barHeight),
        Radius.circular(_barHeight / 2),
      ),
      progressPaint,
    );
    
    // Progress bar border
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _barWidth, _barHeight),
        Radius.circular(_barHeight / 2),
      ),
      borderPaint,
    );
    
    // Progress text
    final String progressText = '$label ${(progress * 100).round()}%';
    final TextSpan textSpan = TextSpan(
      text: progressText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(0.5, 0.5),
            blurRadius: 2,
            color: Colors.black,
          ),
        ],
      ),
    );
    
    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    textPainter.paint(
      canvas,
      Offset(
        barX + _barWidth / 2 - textPainter.width / 2,
        barY - textPainter.height - 2,
      ),
    );
  }
}