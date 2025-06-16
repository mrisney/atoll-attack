import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import 'island_game.dart';
import 'arrow_component.dart';
import 'flag_raise_component.dart';

// Flag raising constants
const double kFlagRaiseDuration = 5.0;
const double kFlagRaiseRange = 8.0;
const bool kFlagRaiseRequiresStationary = true;
const double kFlagRaiseStationaryThreshold = 1.0;

class UnitComponent extends PositionComponent with HasGameRef<IslandGame> {
  final UnitModel model;
  late Paint _fillPaint;
  late Paint _borderPaint;
  late Paint _selectedPaint;

  // Flag raising component (only for captains)
  FlagRaiseComponent? _flagRaiseComponent;
  bool _isAtApex = false;
  bool _wasAtApex = false;

  // Death animation properties
  bool _isPlayingDeathAnimation = false;
  double _deathAnimationTimer = 0.0;
  static const double _deathAnimationDuration = 0.8; // seconds
  double _deathScale = 1.0;
  double _deathOpacity = 1.0;
  double _deathRotation = 0.0;

  // Victory animation properties for defeated units
  bool _isVictoryAnimation = false;
  double _victoryAnimationTimer = 0.0;
  static const double _victoryAnimationDuration = 0.5;
  double _victoryScale = 1.0;

  // Healing animation properties - to be implemented later when ship component is added
  bool _isHealingAnimation = false;
  double _healingAnimationTimer = 0.0;
  static const double _healingAnimationDuration = 1.0;
  double _healingOpacity = 0.0;

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

    // Initialize flag raising component for captains
    if (model.type == UnitType.captain) {
      _flagRaiseComponent = FlagRaiseComponent(
        captain: model,
        teamColor: model.team == Team.blue ? Colors.blue : Colors.red,
      );
      add(_flagRaiseComponent!);
    }

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

  /// Trigger death animation
  void playDeathAnimation() {
    _isPlayingDeathAnimation = true;
    _deathAnimationTimer = 0.0;

    // Stop flag raising if captain dies
    if (_flagRaiseComponent != null) {
      _flagRaiseComponent!.stopRaisingFlag();
    }
  }

  /// Trigger victory animation (for units that win battles)
  void playVictoryAnimation() {
    _isVictoryAnimation = true;
    _victoryAnimationTimer = 0.0;
  }

  /// Trigger healing animation
  void playHealingAnimation() {
    _isHealingAnimation = true;
    _healingAnimationTimer = 0.0;
    _healingOpacity = 1.0;
  }

  /// Check if captain is at apex and can raise flag
  bool _canRaiseFlag() {
    if (model.type != UnitType.captain) return false;
    if (model.health <= 0) return false;
    if (model.hasPlantedFlag) return false; // Already planted

    final apex = gameRef.getIslandApex();
    if (apex == null) return false;

    // Check distance to apex
    final distance = model.position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance > kFlagRaiseRange) return false;

    // Check if captain is stationary (if required)
    if (kFlagRaiseRequiresStationary) {
      return model.velocity.length <= kFlagRaiseStationaryThreshold;
    }

    return true;
  }

  @override
  void render(Canvas canvas) {
    try {
      // Apply death animation transformations
      if (_isPlayingDeathAnimation) {
        canvas.save();
        canvas.scale(_deathScale);
        canvas.rotate(_deathRotation);

        // Apply opacity by modifying paint colors
        _fillPaint.color = model.color.withOpacity(_deathOpacity);
        _borderPaint.color = Colors.black.withOpacity(0.2 * _deathOpacity);
      }

      // Apply victory animation transformations
      if (_isVictoryAnimation) {
        canvas.save();
        canvas.scale(_victoryScale);
      }

      // Skip rendering if dead and animation is complete
      if (model.health <= 0 && !_isPlayingDeathAnimation) return;

      if (gameRef.useAssets && unitSprite != null) {
        _renderWithAssets(canvas);
      } else {
        _renderSimpleShapes(canvas);
      }

      // Always render health bar and selection indicator (unless playing death animation)
      if (!_isPlayingDeathAnimation) {
        _renderHealthBar(canvas);
        if (model.isSelected) {
          _renderSelectionIndicator(canvas);
        }

        // Render flag raising indicator for captains at apex
        if (model.type == UnitType.captain &&
            _isAtApex &&
            !model.hasPlantedFlag) {
          _renderFlagRaiseIndicator(canvas);
        }
      }

      // Restore canvas if transformations were applied
      if (_isPlayingDeathAnimation || _isVictoryAnimation) {
        canvas.restore();
      }
    } catch (e) {
      // Silently handle any rendering errors
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
            ..color = Colors.yellow.withOpacity(_deathOpacity)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);

      // Draw flag if planted (this is now handled by FlagRaiseComponent)
      // Keep this for backward compatibility if flag component isn't loaded
      if (model.hasPlantedFlag && _flagRaiseComponent == null) {
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
              ..color = Colors.white.withOpacity(_deathOpacity)
              ..strokeWidth = 1);
        canvas.drawPath(
            flag,
            Paint()
              ..color = (model.team == Team.blue ? Colors.blue : Colors.red)
                  .withOpacity(_deathOpacity)
              ..style = PaintingStyle.fill);
      }
    } else if (model.type == UnitType.swordsman) {
      // Draw a small shield for swordsman
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2 + 2),
        model.radius * 0.5,
        Paint()
          ..color = Colors.grey.withOpacity(_deathOpacity)
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
            ..color = Colors.brown.withOpacity(_deathOpacity)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }

    // Draw attack indicator if attacking (and not dying)
    if (model.state == UnitState.attacking && !_isPlayingDeathAnimation) {
      _renderAttackIndicator(canvas);
    } else if (model.velocity.length > 0.1 && !_isPlayingDeathAnimation) {
      // Draw direction indicator when moving
      _renderDirectionIndicator(canvas);
    }

    // Draw death effects
    if (_isPlayingDeathAnimation) {
      _renderDeathEffect(canvas);
    }

    // Draw victory effects
    if (_isVictoryAnimation) {
      _renderVictoryEffect(canvas);
    }
  }

  void _renderFlagRaiseIndicator(Canvas canvas) {
    // Draw a subtle indicator that captain can raise flag here
    final Paint indicatorPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw pulsing circle around captain
    final double pulseRadius = model.radius +
        5 +
        math.sin(DateTime.now().millisecondsSinceEpoch / 200) * 2;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      pulseRadius,
      indicatorPaint,
    );

    // Draw "RAISE FLAG" text
    final TextSpan textSpan = TextSpan(
      text: 'RAISE FLAG',
      style: TextStyle(
        color: Colors.yellow,
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

  // Track time since last arrow
  double _timeSinceLastArrow = 0.0;
  static const double _arrowCooldown = 0.8; // seconds between arrows

  void _renderAttackIndicator(Canvas canvas) {
    if (model.type == UnitType.archer) {
      try {
        // Get elevation for range calculation
        double elevation = gameRef.getElevationAt(model.position);
        // Calculate effective range based on elevation
        double effectiveRange = elevation > 0.6 ? 100.0 : model.attackRange;

        // Find nearest enemy to shoot arrows at
        final units = gameRef.getAllUnits();
        UnitComponent? nearestEnemy;
        double nearestDistance = effectiveRange;

        for (final unit in units) {
          if (unit.model.team != model.team && unit.model.health > 0) {
            final distance = model.position.distanceTo(unit.model.position);
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestEnemy = unit;
            }
          }
        }

        if (nearestEnemy != null) {
          // Draw simple indicator for immediate feedback
          final direction = (nearestEnemy.position - position).normalized();
          final start = Vector2(size.x / 2, size.y / 2);

          // Draw targeting line
          canvas.drawLine(
            Offset(start.x, start.y),
            Offset(start.x + direction.x * 20, start.y + direction.y * 20),
            Paint()
              ..color = Colors.white.withOpacity(0.5)
              ..strokeWidth = 1.0,
          );
        }
      } catch (e) {
        // Silently handle any errors in arrow rendering
      }
    } else if (model.type == UnitType.swordsman) {
      // Draw sword slash
      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.x / 2, size.y / 2), radius: model.radius * 1.2),
        -0.5,
        1.0,
        false,
        Paint()
          ..color = Colors.white.withOpacity(_deathOpacity)
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
        ..color = Colors.white.withOpacity(_deathOpacity)
        ..strokeWidth = 2,
    );
  }

  void _renderDeathEffect(Canvas canvas) {
    // Draw some death particles/effects
    final center = Offset(size.x / 2, size.y / 2);

    // Draw fading red crosses or X marks
    final paint = Paint()
      ..color = Colors.red.withOpacity(_deathOpacity * 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw X
    final crossSize = model.radius * 0.8;
    canvas.drawLine(
      center + Offset(-crossSize, -crossSize),
      center + Offset(crossSize, crossSize),
      paint,
    );
    canvas.drawLine(
      center + Offset(-crossSize, crossSize),
      center + Offset(crossSize, -crossSize),
      paint,
    );
  }

  void _renderVictoryEffect(Canvas canvas) {
    // Draw victory sparkles or glow effect
    final center = Offset(size.x / 2, size.y / 2);
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Draw small sparkles around the unit
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi;
      final sparklePos = center +
          Offset(
            math.cos(angle) * model.radius * 1.5,
            math.sin(angle) * model.radius * 1.5,
          );
      canvas.drawCircle(sparklePos, 2, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle flag raising logic for captains
    if (model.type == UnitType.captain && _flagRaiseComponent != null) {
      _wasAtApex = _isAtApex;
      _isAtApex = _canRaiseFlag();

      // Start flag raising if captain just arrived at apex and is stationary
      if (_isAtApex && !_wasAtApex && !_flagRaiseComponent!.isFlagFullyRaised) {
        _flagRaiseComponent!.startRaisingFlag();
      }

      // Stop flag raising if captain moved away from apex or started moving
      if (!_isAtApex && _wasAtApex) {
        _flagRaiseComponent!.stopRaisingFlag();
      }

      // Check if flag is fully raised for victory
      if (_flagRaiseComponent!.isFlagFullyRaised && !model.hasPlantedFlag) {
        model.hasPlantedFlag = true;
        gameRef.captainReachedApex(this);
      }
    }

    // Update death animation
    if (_isPlayingDeathAnimation) {
      _deathAnimationTimer += dt;
      final progress =
          (_deathAnimationTimer / _deathAnimationDuration).clamp(0.0, 1.0);

      // Animate scale (shrinking)
      _deathScale = 1.0 - (progress * 0.8);

      // Animate opacity (fading)
      _deathOpacity = 1.0 - progress;

      // Animate rotation (spinning)
      _deathRotation = progress * math.pi * 2;

      // Complete animation
      if (_deathAnimationTimer >= _deathAnimationDuration) {
        _isPlayingDeathAnimation = false;
      }
      return; // Don't update model during death animation
    }

    // Check if archer should be in attack state based on nearby enemies
    if (model.type == UnitType.archer) {
      try {
        final units = gameRef.getAllUnits();
        // Get elevation for range calculation (with safety check)
        double elevation = 0.0;
        try {
          elevation = gameRef.getElevationAt(model.position);
        } catch (e) {
          // Use default elevation if error occurs
        }

        // Calculate effective range based on elevation
        double effectiveRange = elevation > 0.6 ? 100.0 : model.attackRange;

        // Find nearest enemy in range
        UnitComponent? nearestEnemy;
        double nearestDistance = effectiveRange;

        for (final unit in units) {
          if (unit.model.team != model.team && unit.model.health > 0) {
            final distance = model.position.distanceTo(unit.model.position);
            if (distance <= effectiveRange && distance < nearestDistance) {
              nearestDistance = distance;
              nearestEnemy = unit;
              model.state = UnitState.attacking;
            }
          }
        }

        // Spawn arrow if in attack state and cooldown elapsed
        if (model.state == UnitState.attacking && nearestEnemy != null) {
          _timeSinceLastArrow += 1 / 60; // Approximate for dt
          if (_timeSinceLastArrow >= _arrowCooldown) {
            _timeSinceLastArrow = 0;

            // Create and add arrow component
            final arrow = ArrowComponent(
              startPosition: position.clone(),
              targetPosition: nearestEnemy.position.clone(),
              team: model.team,
            );

            gameRef.add(arrow);
          }
        } else {
          _timeSinceLastArrow =
              _arrowCooldown; // Ready to fire immediately when enemy appears
        }
      } catch (e) {
        // Silently handle any errors in attack state detection
      }
    }

    // Update victory animation
    if (_isVictoryAnimation) {
      _victoryAnimationTimer += dt;
      final progress =
          (_victoryAnimationTimer / _victoryAnimationDuration).clamp(0.0, 1.0);

      // Animate scale (pulsing)
      _victoryScale = 1.0 + (math.sin(progress * math.pi * 4) * 0.2);

      // Complete animation
      if (_victoryAnimationTimer >= _victoryAnimationDuration) {
        _isVictoryAnimation = false;
        _victoryScale = 1.0;
      }
    }

    // Skip update if dead
    if (model.health <= 0) {
      // Start death animation if not already playing
      if (!_isPlayingDeathAnimation) {
        playDeathAnimation();
      }

      // Mark for removal if dead and animation is complete
      if (isMounted && !_isPlayingDeathAnimation) {
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

    // Check if unit just won a battle (defeated an enemy)
    final wasInCombat = model.state == UnitState.attacking;

    // Update unit model using your model's update method signature
    model.update(dt, units, apex, elevationAtPosition: elevation);

    // If unit was in combat and is no longer attacking, play victory animation
    if (wasInCombat &&
        model.state != UnitState.attacking &&
        !_isVictoryAnimation) {
      playVictoryAnimation();
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
    // Set the exact target position from player input
    model.targetPosition = target.clone();

    // Force the unit to prioritize movement to the new target
    model.forceRedirect = true;

    // Reset combat state if unit was engaged
    if (model.state == UnitState.attacking) {
      model.state = UnitState.moving;
    }

    // Stop flag raising if captain is ordered to move
    if (model.type == UnitType.captain && _flagRaiseComponent != null) {
      _flagRaiseComponent!.stopRaisingFlag();
    }

    // Don't use pathfinding - let units move irregularly
    model.path = null;

    // We no longer auto-deselect units to allow for multiple commands
  }

  bool containsPoint(Vector2 point) {
    final center = position + size / 2;
    return center.distanceTo(point) <= model.radius;
  }

  // Show unit information when tapped
  void showUnitInfo() {
    final healthPercent = (model.health / model.maxHealth * 100).toInt();
    final typeStr = model.type.toString().split('.').last;
    final teamStr = model.team.toString().split('.').last;

    String flagStatus = '';
    if (model.type == UnitType.captain) {
      if (model.hasPlantedFlag) {
        flagStatus = '\nFLAG PLANTED!';
      } else if (_flagRaiseComponent != null &&
          _flagRaiseComponent!.progress > 0) {
        flagStatus =
            '\nRaising flag: ${(_flagRaiseComponent!.progress * 100).round()}%';
      } else if (_isAtApex) {
        flagStatus = '\nAt apex - ready to raise flag!';
      }
    }

    // Display unit information using game's notification system
    gameRef.showUnitInfo("Unit: ${typeStr.toUpperCase()}\n"
        "Team: ${teamStr.toUpperCase()}\n"
        "Health: $healthPercent%$flagStatus");
  }
}
