import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import 'ship_model.dart';
import 'island_game.dart';

class ShipComponent extends PositionComponent with HasGameRef<IslandGame> {
  final ShipModel model;
  late Paint _fillPaint;
  late Paint _borderPaint;
  late Paint _selectedPaint;

  // Visual properties
  double _waveOffset = 0.0;
  double _sailAnimation = 0.0;
  bool _showDeploymentUI = false;

  // Sprite placeholder (will be replaced with actual sprite)
  Sprite? shipSprite;

  ShipComponent({required this.model})
      : super(
          position: model.position,
          size: Vector2.all(model.radius * 2),
          anchor: Anchor.center,
        ) {
    _fillPaint = Paint()..color = model.color;
    _borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _selectedPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set up land detection callbacks
    model.isOnLandCallback = (pos) => gameRef.isOnLand(pos);
    model.isNearShoreCallback = (pos) => _isNearShore(pos);

    // Load sprite when available
    if (gameRef.useAssets) {
      await _loadShipSprite();
    }
  }

  Future<void> _loadShipSprite() async {
    try {
      // This will load the turtle ship sprite when available
      shipSprite =
          await Sprite.load('ships/${model.team.name}_turtle_ship.png');
    } catch (e) {
      // Fallback to placeholder rendering
      debugPrint('Ship sprite not available, using placeholder: $e');
    }
  }

  /// Check if position is near shore (within ship radius + buffer)
  bool _isNearShore(Vector2 pos) {
    const double shoreBuffer = 15.0;

    // Check points around the position
    for (int angle = 0; angle < 360; angle += 30) {
      double rad = angle * math.pi / 180;
      Vector2 checkPos = pos +
          Vector2(
            math.cos(rad) * shoreBuffer,
            math.sin(rad) * shoreBuffer,
          );

      if (gameRef.isOnLand(checkPos)) {
        return true;
      }
    }

    return false;
  }

  @override
  void render(Canvas canvas) {
    try {
      // Skip rendering if destroyed
      if (model.isDestroyed) return;

      if (shipSprite != null) {
        _renderWithSprite(canvas);
      } else {
        _renderPlaceholder(canvas);
      }

      // Always render health bar and status indicators
      _renderHealthBar(canvas);

      if (model.isSelected) {
        _renderSelectionIndicator(canvas);
      }

      if (model.isAtShore) {
        _renderShoreIndicator(canvas);
      }

      // Render deployment UI if needed
      if (_showDeploymentUI) {
        _renderDeploymentUI(canvas);
      }
    } catch (e) {
      // Silently handle any rendering errors
    }
  }

  void _renderWithSprite(Canvas canvas) {
    // This will render the actual turtle ship sprite when available
    shipSprite!.render(canvas, position: Vector2.zero(), size: size);
  }

  void _renderPlaceholder(Canvas canvas) {
    // Placeholder turtle ship rendering
    final center = Offset(size.x / 2, size.y / 2);

    // Ship hull (oval shape)
    final hullRect = Rect.fromCenter(
      center: center,
      width: model.radius * 1.8,
      height: model.radius * 1.2,
    );

    canvas.drawOval(hullRect, _fillPaint);
    canvas.drawOval(hullRect, _borderPaint);

    // Turtle shell spikes on top
    _renderTurtleSpikes(canvas, center);

    // Sail (if present)
    if (model.hasSail) {
      _renderSail(canvas, center);
    }

    // Cannon ports
    _renderCannonPorts(canvas, center);

    // Paddles (if using paddles)
    if (model.usingPaddles) {
      _renderPaddles(canvas, center);
    }

    // Team indicator
    _renderTeamIndicator(canvas, center);
  }

  void _renderTurtleSpikes(Canvas canvas, Offset center) {
    final spikePaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.fill;

    // Draw spikes along the top of the ship
    for (int i = 0; i < 5; i++) {
      double x = center.dx - model.radius * 0.8 + (i * model.radius * 0.4);
      double y = center.dy - model.radius * 0.6;

      final spikePath = Path()
        ..moveTo(x - 3, y)
        ..lineTo(x, y - 8)
        ..lineTo(x + 3, y)
        ..close();

      canvas.drawPath(spikePath, spikePaint);
    }
  }

  void _renderSail(Canvas canvas, Offset center) {
    // Mast
    final mastPaint = Paint()
      ..color = Colors.brown.shade600
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx, center.dy - model.radius * 0.3),
      Offset(center.dx, center.dy - model.radius * 1.5),
      mastPaint,
    );

    // Sail with animation
    _sailAnimation += 0.02;
    double sailWave = math.sin(_sailAnimation) * 2;

    final sailPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final sailPath = Path()
      ..moveTo(center.dx, center.dy - model.radius * 1.4)
      ..lineTo(center.dx + model.radius * 0.8 + sailWave,
          center.dy - model.radius * 1.2)
      ..lineTo(center.dx + model.radius * 0.8, center.dy - model.radius * 0.5)
      ..lineTo(center.dx, center.dy - model.radius * 0.4)
      ..close();

    canvas.drawPath(sailPath, sailPaint);
    canvas.drawPath(sailPath, _borderPaint);
  }

  void _renderCannonPorts(Canvas canvas, Offset center) {
    final cannonPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // Left side cannons
    for (int i = 0; i < model.cannonsPerSide; i++) {
      double y = center.dy - model.radius * 0.3 + (i * model.radius * 0.3);
      canvas.drawCircle(
        Offset(center.dx - model.radius * 0.8, y),
        3,
        cannonPaint,
      );
    }

    // Right side cannons
    for (int i = 0; i < model.cannonsPerSide; i++) {
      double y = center.dy - model.radius * 0.3 + (i * model.radius * 0.3);
      canvas.drawCircle(
        Offset(center.dx + model.radius * 0.8, y),
        3,
        cannonPaint,
      );
    }
  }

  void _renderPaddles(Canvas canvas, Offset center) {
    final paddlePaint = Paint()
      ..color = Colors.brown.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Animate paddles
    _waveOffset += 0.1;
    double paddleOffset = math.sin(_waveOffset) * 5;

    // Left paddles
    for (int i = 0; i < 3; i++) {
      double y = center.dy - 10 + (i * 10);
      canvas.drawLine(
        Offset(center.dx - model.radius * 0.9, y),
        Offset(center.dx - model.radius * 1.2, y + paddleOffset),
        paddlePaint,
      );
    }

    // Right paddles
    for (int i = 0; i < 3; i++) {
      double y = center.dy - 10 + (i * 10);
      canvas.drawLine(
        Offset(center.dx + model.radius * 0.9, y),
        Offset(center.dx + model.radius * 1.2, y - paddleOffset),
        paddlePaint,
      );
    }
  }

  void _renderTeamIndicator(Canvas canvas, Offset center) {
    final teamPaint = Paint()
      ..color = model.team == Team.blue ? Colors.blue : Colors.red
      ..style = PaintingStyle.fill;

    // Team flag on the mast
    final flagRect = Rect.fromCenter(
      center: Offset(center.dx + 8, center.dy - model.radius * 1.3),
      width: 12,
      height: 8,
    );

    canvas.drawRect(flagRect, teamPaint);
    canvas.drawRect(flagRect, _borderPaint);
  }

  void _renderHealthBar(Canvas canvas) {
    final healthPercent = model.healthPercent;

    if (healthPercent < 1.0) {
      // Background
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 10,
            model.radius * 2, 4),
        Paint()..color = Colors.grey.withOpacity(0.7),
      );

      // Health amount
      Color healthColor = healthPercent > 0.6
          ? Colors.green
          : (healthPercent > 0.3 ? Colors.orange : Colors.red);

      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 10,
            model.radius * 2 * healthPercent, 4),
        Paint()..color = healthColor,
      );

      // Health bar border
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 10,
            model.radius * 2, 4),
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _renderSelectionIndicator(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      model.radius + 5,
      _selectedPaint,
    );
  }

  void _renderShoreIndicator(Canvas canvas) {
    // Pulsing indicator when at shore
    double pulseRadius = model.radius + 8 + math.sin(_waveOffset * 2) * 3;
    final shorePaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      pulseRadius,
      shorePaint,
    );

    // "AT SHORE" text
    final TextSpan textSpan = TextSpan(
      text: 'AT SHORE',
      style: TextStyle(
        color: Colors.green,
        fontSize: 10,
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
        size.x / 2 - textPainter.width / 2,
        size.y / 2 - model.radius - 25,
      ),
    );
  }

  void _renderDeploymentUI(Canvas canvas) {
    // This will be implemented when we add the deployment UI
    // For now, just show a simple indicator
    final deployPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 + model.radius + 15),
      5,
      deployPaint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update wave and animation offsets
    _waveOffset += dt;

    // Update model
    model.update(dt);

    // Update component position from model
    position.setFrom(model.position);
  }

  /// Handle tap on ship
  void onTap() {
    model.isSelected = !model.isSelected;

    if (model.isSelected && model.isAtShore) {
      _showDeploymentUI = true;
    } else {
      _showDeploymentUI = false;
    }

    // Show ship info
    showShipInfo();
  }

  /// Set target position for ship movement
  void setTargetPosition(Vector2 target) {
    model.setTargetPosition(target);
  }

  /// Show ship information
  void showShipInfo() {
    final available = model.getAvailableUnits();
    final status = model.getStatusText();
    final healthPercent = (model.healthPercent * 100).round();

    String cargoInfo = "Cargo: ";
    cargoInfo += "C:${available[UnitType.captain]} ";
    cargoInfo += "A:${available[UnitType.archer]} ";
    cargoInfo += "S:${available[UnitType.swordsman]}";

    gameRef.showUnitInfo(
        "TURTLE SHIP (${model.team.toString().split('.').last.toUpperCase()})\n"
        "Health: $healthPercent%\n"
        "Status: $status\n"
        "$cargoInfo");
  }

  /// Deploy a unit of specified type
  UnitType? deployUnit(UnitType type) {
    if (!model.canDeployUnits()) return null;

    return model.deployUnit(type);
  }

  /// Get deployment position
  Vector2? getDeploymentPosition() {
    return model.getDeploymentPosition();
  }

  /// Check if point is within ship bounds
  bool containsPoint(Vector2 point) {
    final center = position + size / 2;
    return center.distanceTo(point) <= model.radius;
  }
}
