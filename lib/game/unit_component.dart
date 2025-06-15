import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import 'island_game.dart';

class UnitComponent extends PositionComponent with HasGameRef<IslandGame> {
  final UnitModel model;
  late Paint _fillPaint;
  late Paint _borderPaint;
  late Paint _selectedPaint;

  // Will be used when artwork is available
  Sprite? unitSprite;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;

  UnitComponent({required this.model})
      : super(
          position: model.position,
          size: Vector2.all(model.radius * 2),
          anchor: Anchor.center,
        ) {
    _fillPaint = Paint()..color = model.color;
    _borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    _selectedPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // This will be implemented when artwork is available
    if (gameRef.useAssets) {
      await _loadAssets();
    }
  }

  Future<void> _loadAssets() async {
    // Placeholder for future asset loading
    // Will be implemented when artwork is available
    final String unitPath = 'units/${model.team.name}_${model.type.name}';

    try {
      // Load static sprite
      unitSprite = await Sprite.load('$unitPath/idle.png');

      // Load animations
      walkAnimation = await SpriteAnimation.load(
        '$unitPath/walk.png',
        SpriteAnimationData.sequenced(
          amount: 8,
          stepTime: 0.1,
          textureSize: Vector2(64, 64),
        ),
      );

      attackAnimation = await SpriteAnimation.load(
        '$unitPath/attack.png',
        SpriteAnimationData.sequenced(
          amount: 5,
          stepTime: 0.1,
          textureSize: Vector2(64, 64),
        ),
      );
    } catch (e) {
      // Fallback to simple shapes if assets fail to load
      debugPrint('Failed to load assets for ${model.type}: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    // Skip rendering if dead
    if (model.health <= 0) return;

    if (gameRef.useAssets && unitSprite != null) {
      _renderWithAssets(canvas);
    } else {
      _renderSimpleShapes(canvas);
    }

    // Always render health bar and selection indicator
    _renderHealthBar(canvas);
    if (model.isSelected) {
      _renderSelectionIndicator(canvas);
    }
  }

  void _renderWithAssets(Canvas canvas) {
    // This will be implemented when artwork is available
    if (model.state == UnitState.moving && walkAnimation != null) {
      // Use direct sprite rendering instead of animation methods
      unitSprite?.render(canvas, position: Vector2.zero(), size: size);
    } else if (model.state == UnitState.attacking && attackAnimation != null) {
      // Use direct sprite rendering instead of animation methods
      unitSprite?.render(canvas, position: Vector2.zero(), size: size);
    } else if (unitSprite != null) {
      unitSprite!.render(canvas, position: Vector2.zero(), size: size);
    }
  }

  void _renderSimpleShapes(Canvas canvas) {
    // Draw unit body
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      model.radius,
      _fillPaint,
    );

    // Draw border
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      model.radius,
      _borderPaint,
    );

    // Draw unit type indicator
    if (model.type == UnitType.captain) {
      // Draw a small crown for captain
      final crownPath = Path()
        ..moveTo(size.x / 2 - 3, size.y / 2 - 2)
        ..lineTo(size.x / 2 - 1, size.y / 2 - 4)
        ..lineTo(size.x / 2, size.y / 2 - 2)
        ..lineTo(size.x / 2 + 1, size.y / 2 - 4)
        ..lineTo(size.x / 2 + 3, size.y / 2 - 2);

      canvas.drawPath(
          crownPath,
          Paint()
            ..color = Colors.yellow
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);

      // Draw flag if planted
      if (model.hasPlantedFlag) {
        final flagPole = Path()
          ..moveTo(size.x / 2, size.y / 2 - 5)
          ..lineTo(size.x / 2, size.y / 2 - 12);

        final flag = Path()
          ..moveTo(size.x / 2, size.y / 2 - 12)
          ..lineTo(size.x / 2 + 5, size.y / 2 - 10)
          ..lineTo(size.x / 2, size.y / 2 - 8);

        canvas.drawPath(
            flagPole,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1);
        canvas.drawPath(
            flag,
            Paint()
              ..color = model.team == Team.blue ? Colors.blue : Colors.red
              ..style = PaintingStyle.fill);
      }
    } else if (model.type == UnitType.swordsman) {
      // Draw a small shield for swordsman
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2 + 2),
        model.radius * 0.5,
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else if (model.type == UnitType.archer) {
      // Draw a small bow for archer
      final bow = Path()
        ..addArc(
          Rect.fromCircle(
              center: Offset(size.x / 2, size.y / 2),
              radius: model.radius * 0.6),
          -0.8,
          1.6,
        );

      canvas.drawPath(
          bow,
          Paint()
            ..color = Colors.brown
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }

    // Draw attack indicator if attacking
    if (model.state == UnitState.attacking) {
      _renderAttackIndicator(canvas);
    } else if (model.velocity.length > 0.1) {
      // Draw direction indicator when moving
      _renderDirectionIndicator(canvas);
    }
  }

  void _renderHealthBar(Canvas canvas) {
    final healthPercent = model.health / model.maxHealth;
    if (healthPercent < 1.0) {
      // Background
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 5,
            model.radius * 2, 3),
        Paint()..color = Colors.grey.withOpacity(0.5),
      );

      // Health amount
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 5,
            model.radius * 2 * healthPercent, 3),
        Paint()
          ..color = healthPercent > 0.5
              ? Colors.green
              : (healthPercent > 0.25 ? Colors.orange : Colors.red),
      );
    }
  }

  void _renderSelectionIndicator(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      model.radius + 3,
      _selectedPaint,
    );
  }

  void _renderAttackIndicator(Canvas canvas) {
    if (model.type == UnitType.archer) {
      // Draw arrow
      final direction = model.velocity.normalized();
      final start = Vector2(size.x / 2, size.y / 2);
      final end = start + direction * model.radius * 2;

      canvas.drawLine(
        Offset(start.x, start.y),
        Offset(end.x, end.y),
        Paint()
          ..color = Colors.yellow
          ..strokeWidth = 1,
      );
    } else if (model.type == UnitType.swordsman) {
      // Draw sword slash
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.x / 2, size.y / 2), radius: model.radius * 1.2),
        -0.5,
        1.0,
        false,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _renderDirectionIndicator(Canvas canvas) {
    final Vector2 direction = model.velocity.normalized();
    final Vector2 start = Vector2(size.x / 2, size.y / 2);
    final Vector2 end = start + direction * model.radius;

    canvas.drawLine(
      Offset(start.x, start.y),
      Offset(end.x, end.y),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Skip update if dead
    if (model.health <= 0) {
      // Mark for removal if dead
      if (isMounted) {
        removeFromParent();
        // Also remove from game's unit list
        gameRef.getAllUnits().remove(this);
      }
      return;
    }

    // Get all units for flocking
    final units = gameRef.getAllUnits().map((comp) => comp.model).toList();

    // Get island apex for navigation target
    final apex = gameRef.getIslandApex();

    // Get elevation at current position for terrain checking
    double elevation = gameRef.getElevationAt(model.position);

    // Update unit model using your model's update method signature
    model.update(dt, units, apex, elevationAtPosition: elevation);

    // Check for captain victory
    if (model.type == UnitType.captain && model.hasPlantedFlag) {
      gameRef.captainReachedApex(this);
    }

    // Update component position from model
    position.setFrom(model.position);

    // Check victory conditions periodically
    gameRef.checkVictoryConditions();
  }

  void setSelected(bool selected) {
    model.isSelected = selected;
  }

  void setTargetPosition(Vector2 target) {
    model.targetPosition = target;

    // Get the apex as the target
    final apex = gameRef.getIslandApex();
    if (apex != null) {
      model.targetPosition = Vector2(apex.dx, apex.dy);
    }

    // Don't use pathfinding - let units move irregularly
    model.path = null;
  }

  bool containsPoint(Vector2 point) {
    final center = position + size / 2;
    return center.distanceTo(point) <= model.radius;
  }
}
