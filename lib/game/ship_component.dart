// Complete ship_component.dart with enhanced tap controls and visual feedback

import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import '../models/ship_model.dart';
import '../game/island_game.dart';

class ShipComponent extends PositionComponent with HasGameRef<IslandGame> {
  final ShipModel model;
  late Paint _fillPaint;
  late Paint _borderPaint;
  late Paint _selectedPaint;
  late Paint _navigationPaint;

  // Visual properties
  double _waveOffset = 0.0;
  double _sailAnimation = 0.0;
  bool _showDeploymentUI = false;
  double _selectionPulse = 0.0;

  // Navigation visualization
  bool _showNavigationPath = false;
  double _pathVisualizationTimer = 0.0;

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
    _navigationPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
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
    if (gameRef.isOnLand == null) return false;

    // Multiple detection methods for better reliability
    const double shoreBuffer = 35.0; // Increased detection range
    const int checkPoints = 16; // More check points for better coverage

    // Method 1: Check points around the ship in a circle
    for (int angle = 0; angle < 360; angle += (360 ~/ checkPoints)) {
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

    // Method 2: Check closer points with smaller radius
    const double closeBuffer = 20.0;
    for (int angle = 0; angle < 360; angle += 45) {
      double rad = angle * math.pi / 180;
      Vector2 checkPos = pos +
          Vector2(
            math.cos(rad) * closeBuffer,
            math.sin(rad) * closeBuffer,
          );

      if (gameRef.isOnLand(checkPos)) {
        return true;
      }
    }

    // Method 3: Check multiple distances in cardinal directions
    List<Vector2> directions = [
      Vector2(1, 0), // East
      Vector2(-1, 0), // West
      Vector2(0, 1), // South
      Vector2(0, -1), // North
      Vector2(1, 1), // Southeast
      Vector2(-1, 1), // Southwest
      Vector2(1, -1), // Northeast
      Vector2(-1, -1), // Northwest
    ];

    for (Vector2 dir in directions) {
      for (double distance = 15.0; distance <= 40.0; distance += 5.0) {
        Vector2 checkPos = pos + dir * distance;
        if (gameRef.isOnLand(checkPos)) {
          return true;
        }
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

      // Always render status indicators
      _renderHealthBar(canvas);
      _renderStatusIndicators(canvas);

      // Render navigation path if ship is selected and navigating
      if (model.isSelected && model.isNavigating && _showNavigationPath) {
        _renderNavigationPath(canvas);
      }

      // Render selection indicator with enhanced visuals
      if (model.isSelected) {
        _renderEnhancedSelectionIndicator(canvas);
        _renderShoreDetectionDebug(canvas);
      }

      // Render deployment UI if needed
      if (_showDeploymentUI) {
        _renderDeploymentUI(canvas);
      }
    } catch (e) {
      // Silently handle any rendering errors
      debugPrint('Ship render error: $e');
    }
  }

  void _renderWithSprite(Canvas canvas) {
    // This will render the actual turtle ship sprite when available
    shipSprite!.render(canvas, position: Vector2.zero(), size: size);
  }

  void _renderPlaceholder(Canvas canvas) {
    // Enhanced placeholder turtle ship rendering
    final center = Offset(size.x / 2, size.y / 2);

    // Ship hull with enhanced shape
    _renderEnhancedHull(canvas, center);

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

    // Wake effects when moving
    if (model.velocity.length > 1.0) {
      _renderWakeEffects(canvas, center);
    }
  }

  void _renderEnhancedHull(Canvas canvas, Offset center) {
    // Main hull with gradient effect
    final hullRect = Rect.fromCenter(
      center: center,
      width: model.radius * 1.8,
      height: model.radius * 1.2,
    );

    // Create gradient for 3D effect
    final gradient = RadialGradient(
      colors: [
        model.color.withOpacity(0.9),
        model.color.withOpacity(0.6),
        model.color.withOpacity(0.8),
      ],
      stops: const [0.3, 0.7, 1.0],
    );

    final gradientPaint = Paint()
      ..shader = gradient.createShader(hullRect)
      ..style = PaintingStyle.fill;

    canvas.drawOval(hullRect, gradientPaint);
    canvas.drawOval(hullRect, _borderPaint);

    // Add hull details
    final detailPaint = Paint()
      ..color = Colors.brown.shade600
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Hull lines for detail
    for (int i = -1; i <= 1; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + i * 8),
          width: model.radius * 1.6,
          height: model.radius * 0.8,
        ),
        detailPaint,
      );
    }
  }

  void _renderTurtleSpikes(Canvas canvas, Offset center) {
    final spikePaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.fill;

    // Draw more prominent spikes
    for (int i = 0; i < 6; i++) {
      double x = center.dx - model.radius * 0.9 + (i * model.radius * 0.36);
      double y = center.dy - model.radius * 0.7;

      final spikePath = Path()
        ..moveTo(x - 4, y)
        ..lineTo(x, y - 12)
        ..lineTo(x + 4, y)
        ..close();

      canvas.drawPath(spikePath, spikePaint);

      // Add spike highlights
      final highlightPaint = Paint()
        ..color = Colors.brown.shade600
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      canvas.drawPath(spikePath, highlightPaint);
    }
  }

  void _renderSail(Canvas canvas, Offset center) {
    // Enhanced mast
    final mastPaint = Paint()
      ..color = Colors.brown.shade600
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx, center.dy - model.radius * 0.3),
      Offset(center.dx, center.dy - model.radius * 1.6),
      mastPaint,
    );

    // Sail with enhanced animation and wind effect
    _sailAnimation += 0.03;
    double sailWave = math.sin(_sailAnimation) * 3;
    double windEffect = math.cos(_sailAnimation * 0.7) * 1.5;

    final sailPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;

    final sailShadowPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;

    // Sail shadow for depth
    final shadowPath = Path()
      ..moveTo(center.dx + 2, center.dy - model.radius * 1.5 + 2)
      ..lineTo(center.dx + model.radius * 0.85 + sailWave + 2,
          center.dy - model.radius * 1.3 + 2)
      ..lineTo(center.dx + model.radius * 0.85 + windEffect + 2,
          center.dy - model.radius * 0.4 + 2)
      ..lineTo(center.dx + 2, center.dy - model.radius * 0.3 + 2)
      ..close();

    canvas.drawPath(shadowPath, sailShadowPaint);

    // Main sail
    final sailPath = Path()
      ..moveTo(center.dx, center.dy - model.radius * 1.5)
      ..lineTo(center.dx + model.radius * 0.85 + sailWave,
          center.dy - model.radius * 1.3)
      ..lineTo(center.dx + model.radius * 0.85 + windEffect,
          center.dy - model.radius * 0.4)
      ..lineTo(center.dx, center.dy - model.radius * 0.3)
      ..close();

    canvas.drawPath(sailPath, sailPaint);
    canvas.drawPath(sailPath, _borderPaint);

    // Team emblem on sail
    if (model.team == Team.blue) {
      _drawTeamEmblem(
          canvas,
          Offset(
              center.dx + model.radius * 0.4, center.dy - model.radius * 0.9),
          Colors.blue.shade700);
    } else {
      _drawTeamEmblem(
          canvas,
          Offset(
              center.dx + model.radius * 0.4, center.dy - model.radius * 0.9),
          Colors.red.shade700);
    }
  }

  void _drawTeamEmblem(Canvas canvas, Offset position, Color color) {
    final emblemPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Simple geometric emblem
    final emblemPath = Path()
      ..addOval(Rect.fromCenter(center: position, width: 12, height: 12));

    canvas.drawPath(emblemPath, emblemPaint);

    // Add team letter
    final textSpan = TextSpan(
      text: model.team == Team.blue ? 'B' : 'R',
      style: TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        position.dx - textPainter.width / 2,
        position.dy - textPainter.height / 2,
      ),
    );
  }

  void _renderCannonPorts(Canvas canvas, Offset center) {
    final cannonPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final cannonBrassPaint = Paint()
      ..color = Colors.yellow.shade700
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Enhanced cannon ports with brass rings
    for (int side = 0; side < 2; side++) {
      double sideMultiplier = side == 0 ? -1 : 1;

      for (int i = 0; i < model.cannonsPerSide; i++) {
        double y = center.dy - model.radius * 0.3 + (i * model.radius * 0.3);
        double x = center.dx + sideMultiplier * model.radius * 0.8;

        // Cannon barrel
        canvas.drawCircle(Offset(x, y), 4, cannonPaint);
        // Brass ring
        canvas.drawCircle(Offset(x, y), 4, cannonBrassPaint);
      }
    }
  }

  void _renderPaddles(Canvas canvas, Offset center) {
    final paddlePaint = Paint()
      ..color = Colors.brown.shade400
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Enhanced animated paddles
    _waveOffset += 0.15;
    double paddleOffset = math.sin(_waveOffset) * 8;

    for (int side = 0; side < 2; side++) {
      double sideMultiplier = side == 0 ? -1 : 1;
      double currentOffset = paddleOffset * sideMultiplier;

      for (int i = 0; i < 3; i++) {
        double y = center.dy - 15 + (i * 15);
        double startX = center.dx + sideMultiplier * model.radius * 0.9;
        double endX = center.dx + sideMultiplier * model.radius * 1.3;

        canvas.drawLine(
          Offset(startX, y),
          Offset(endX, y + currentOffset),
          paddlePaint,
        );

        // Paddle blade
        final bladePaint = Paint()
          ..color = Colors.brown.shade600
          ..style = PaintingStyle.fill;

        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(endX, y + currentOffset),
            width: 8,
            height: 4,
          ),
          bladePaint,
        );
      }
    }
  }

  void _renderTeamIndicator(Canvas canvas, Offset center) {
    final teamPaint = Paint()
      ..color = model.team == Team.blue ? Colors.blue : Colors.red
      ..style = PaintingStyle.fill;

    // Enhanced team flag on the mast
    final flagRect = Rect.fromCenter(
      center: Offset(center.dx + 10, center.dy - model.radius * 1.4),
      width: 16,
      height: 10,
    );

    canvas.drawRect(flagRect, teamPaint);
    canvas.drawRect(flagRect, _borderPaint);
  }

  void _renderWakeEffects(Canvas canvas, Offset center) {
    final wakePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Get movement direction for wake
    Vector2 velocity = model.velocity;
    if (velocity.length > 0) {
      velocity.normalize();

      // Draw wake lines behind the ship
      for (int i = 0; i < 3; i++) {
        double distance = (i + 1) * 15;
        Vector2 wakeStart = Vector2(center.dx, center.dy) - velocity * distance;
        Vector2 wakeEnd = wakeStart - velocity * 10;

        // Add some spread to the wake
        double spread = (i + 1) * 3;
        Vector2 perpendicular = Vector2(-velocity.y, velocity.x);

        // Left wake line
        Vector2 leftStart = wakeStart + perpendicular * spread;
        Vector2 leftEnd = wakeEnd + perpendicular * spread;
        canvas.drawLine(
          Offset(leftStart.x, leftStart.y),
          Offset(leftEnd.x, leftEnd.y),
          wakePaint,
        );

        // Right wake line
        Vector2 rightStart = wakeStart - perpendicular * spread;
        Vector2 rightEnd = wakeEnd - perpendicular * spread;
        canvas.drawLine(
          Offset(rightStart.x, rightStart.y),
          Offset(rightEnd.x, rightEnd.y),
          wakePaint,
        );
      }
    }
  }

  void _renderStatusIndicators(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    if (model.isAtShore) {
      _renderShoreIndicator(canvas, center);
    }

    if (model.isStuck) {
      _renderStuckIndicator(canvas, center);
    }

    if (model.isNavigating) {
      _renderNavigatingIndicator(canvas, center);
    }
  }

  void _renderShoreIndicator(Canvas canvas, Offset center) {
    // Pulsing green indicator when at shore
    double pulseRadius = model.radius + 8 + math.sin(_waveOffset * 2) * 3;
    final shorePaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, pulseRadius, shorePaint);

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
        center.dx - textPainter.width / 2,
        center.dy - model.radius - 30,
      ),
    );
  }

  void _renderStuckIndicator(Canvas canvas, Offset center) {
    // Red warning indicator when stuck
    final stuckPaint = Paint()
      ..color = Colors.red.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, model.radius + 5, stuckPaint);

    // Warning icon
    final TextSpan textSpan = TextSpan(
      text: '⚠ STUCK',
      style: TextStyle(
        color: Colors.red,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
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
        center.dx - textPainter.width / 2,
        center.dy - model.radius - 35,
      ),
    );
  }

  void _renderNavigatingIndicator(Canvas canvas, Offset center) {
    // Cyan indicator when navigating
    double pulseRadius = model.radius + 6 + math.sin(_waveOffset * 3) * 2;
    final navPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, pulseRadius, navPaint);

    // Navigation text
    final TextSpan textSpan = TextSpan(
      text: 'NAVIGATING',
      style: TextStyle(
        color: Colors.cyan,
        fontSize: 9,
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
        center.dx - textPainter.width / 2,
        center.dy + model.radius + 15,
      ),
    );
  }

  void _renderNavigationPath(Canvas canvas) {
    if (model.navigationPath == null || model.navigationPath!.isEmpty) return;

    final pathPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final waypointPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Draw path lines
    Vector2 currentPos = position;
    for (int i = 0; i < model.navigationPath!.length; i++) {
      Vector2 waypoint = model.navigationPath![i];

      // Convert to local coordinates relative to ship component
      Vector2 localWaypoint = waypoint - position;
      Vector2 localCurrent = currentPos - position;

      canvas.drawLine(
        Offset(localCurrent.x + size.x / 2, localCurrent.y + size.y / 2),
        Offset(localWaypoint.x + size.x / 2, localWaypoint.y + size.y / 2),
        pathPaint,
      );

      // Draw waypoint marker
      canvas.drawCircle(
        Offset(localWaypoint.x + size.x / 2, localWaypoint.y + size.y / 2),
        4,
        waypointPaint,
      );

      currentPos = waypoint;
    }

    // Highlight current target waypoint
    if (model.getCurrentWaypointIndex() < model.navigationPath!.length) {
      Vector2 currentTarget =
          model.navigationPath![model.getCurrentWaypointIndex()];
      Vector2 localTarget = currentTarget - position;

      final targetPaint = Paint()
        ..color = Colors.yellow.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(localTarget.x + size.x / 2, localTarget.y + size.y / 2),
        6,
        targetPaint,
      );
    }
  }

  void _renderHealthBar(Canvas canvas) {
    final healthPercent = model.healthPercent;

    if (healthPercent < 1.0) {
      // Background
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 12,
            model.radius * 2, 6),
        Paint()..color = Colors.grey.withOpacity(0.7),
      );

      // Health amount with gradient
      Color healthColor = healthPercent > 0.6
          ? Colors.green
          : (healthPercent > 0.3 ? Colors.orange : Colors.red);

      final healthPaint = Paint()
        ..color = healthColor
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 12,
            model.radius * 2 * healthPercent, 6),
        healthPaint,
      );

      // Health bar border
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 12,
            model.radius * 2, 6),
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // Health percentage text
      if (healthPercent < 0.8) {
        final TextSpan textSpan = TextSpan(
          text: '${(healthPercent * 100).round()}%',
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
            size.x / 2 - textPainter.width / 2,
            size.y / 2 - model.radius - 25,
          ),
        );
      }
    }
  }

  void _renderEnhancedSelectionIndicator(Canvas canvas) {
    // Animated selection ring
    _selectionPulse += 0.05;
    double pulseRadius = model.radius + 8 + math.sin(_selectionPulse * 2) * 2;

    final selectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      pulseRadius,
      selectionPaint,
    );

    // Selection corners for better visibility
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    double cornerSize = 8;
    double cornerOffset = model.radius + 12;
    Offset center = Offset(size.x / 2, size.y / 2);

    // Draw corner brackets
    List<Offset> corners = [
      Offset(center.dx - cornerOffset, center.dy - cornerOffset),
      Offset(center.dx + cornerOffset, center.dy - cornerOffset),
      Offset(center.dx - cornerOffset, center.dy + cornerOffset),
      Offset(center.dx + cornerOffset, center.dy + cornerOffset),
    ];

    for (Offset corner in corners) {
      // Horizontal lines
      canvas.drawLine(
        Offset(corner.dx - cornerSize / 2, corner.dy),
        Offset(corner.dx + cornerSize / 2, corner.dy),
        cornerPaint,
      );
      // Vertical lines
      canvas.drawLine(
        Offset(corner.dx, corner.dy - cornerSize / 2),
        Offset(corner.dx, corner.dy + cornerSize / 2),
        cornerPaint,
      );
    }

    // Selected ship info
    final TextSpan textSpan = TextSpan(
      text: 'SELECTED',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
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
        size.y / 2 + model.radius + 20,
      ),
    );
  }

  void _renderDeploymentUI(Canvas canvas) {
    // Enhanced deployment UI indicator
    final deployPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final deployBorderPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Deployment indicator icon
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 + model.radius + 20),
      8,
      deployPaint,
    );

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 + model.radius + 20),
      8,
      deployBorderPaint,
    );

    // Deployment icon (arrow down)
    final iconPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final arrowPath = Path()
      ..moveTo(size.x / 2, size.y / 2 + model.radius + 15)
      ..lineTo(size.x / 2, size.y / 2 + model.radius + 25)
      ..moveTo(size.x / 2 - 3, size.y / 2 + model.radius + 22)
      ..lineTo(size.x / 2, size.y / 2 + model.radius + 25)
      ..lineTo(size.x / 2 + 3, size.y / 2 + model.radius + 22);

    canvas.drawPath(arrowPath, iconPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update wave and animation offsets
    _waveOffset += dt;
    _pathVisualizationTimer += dt;

    // Show navigation path for a few seconds after setting target
    if (model.isNavigating && _pathVisualizationTimer < 5.0) {
      _showNavigationPath = true;
    } else {
      _showNavigationPath = false;
      _pathVisualizationTimer = 0.0;
    }

    // Update model
    model.update(dt);

    // Update component position from model
    position.setFrom(model.position);
  }

  /// Handle tap on ship - enhanced for better feedback
  void onTap() {
    // Visual feedback
    _selectionPulse = 0.0;
    _pathVisualizationTimer = 0.0;

    // Toggle selection state
    model.isSelected = !model.isSelected;

    if (model.isSelected && model.isAtShore) {
      _showDeploymentUI = true;
    } else {
      _showDeploymentUI = false;
    }

    // Show enhanced ship info
    showShipInfo();
  }

  /// Set target position for ship movement with visual feedback
  void setTargetPosition(Vector2 target) {
    model.setTargetPosition(target);

    // Reset visualization timer to show path
    _pathVisualizationTimer = 0.0;
    _showNavigationPath = true;

    // Visual feedback for setting target
    _selectionPulse = 0.0;
  }

  /// Show enhanced ship information
  void showShipInfo() {
    final available = model.getAvailableUnits();
    final status = model.getStatusText();
    final healthPercent = (model.healthPercent * 100).round();

    String cargoInfo = "Cargo: ";
    cargoInfo += "C:${available[UnitType.captain]} ";
    cargoInfo += "A:${available[UnitType.archer]} ";
    cargoInfo += "S:${available[UnitType.swordsman]}";

    String navigationInfo = "";
    if (model.isNavigating && model.navigationPath != null) {
      navigationInfo = "\nWaypoints: ${model.navigationPath!.length}";
    }

    gameRef.showUnitInfo(
        "TURTLE SHIP (${model.team.toString().split('.').last.toUpperCase()})\n"
        "Health: $healthPercent%\n"
        "Status: $status\n"
        "$cargoInfo$navigationInfo\n"
        "Tap empty water to move");
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

  /// Check if point is within ship bounds (enhanced for better tap detection)
  bool containsPoint(Vector2 point) {
    final center = position + size / 2;
    return center.distanceTo(point) <=
        (model.radius + 10); // Slightly larger tap area
  }

  /// Debug method to visualize shore detection
  void _renderShoreDetectionDebug(Canvas canvas) {
    if (!model.isSelected) return; // Only show for selected ships

    final center = Offset(size.x / 2, size.y / 2);

    // Draw shore detection radius
    final debugPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Show detection circles
    List<double> radii = [15.0, 25.0, 35.0];
    for (double radius in radii) {
      canvas.drawCircle(center, radius, debugPaint);
    }

    // Show detection points
    const double checkRadius = 30.0;
    final pointPaint = Paint()
      ..color = Colors.orange.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int angle = 0; angle < 360; angle += 30) {
      double rad = angle * math.pi / 180;
      Offset checkPoint = center +
          Offset(
            math.cos(rad) * checkRadius,
            math.sin(rad) * checkRadius,
          );

      canvas.drawCircle(checkPoint, 2, pointPaint);
    }

    // Show shore status
    final statusText = model.isAtShore ? 'SHORE: YES' : 'SHORE: NO';
    final TextSpan textSpan = TextSpan(
      text: statusText,
      style: TextStyle(
        color: model.isAtShore ? Colors.green : Colors.red,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
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
        center.dx - textPainter.width / 2,
        center.dy - model.radius - 50,
      ),
    );
  }
}
