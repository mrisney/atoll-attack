import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import 'island_game.dart';
import 'arrow_component.dart';
import 'flag_raise_component.dart';
import 'progress_bar_component.dart';

// Import flag raising constants from config
import '../constants/game_config.dart';

class UnitComponent extends PositionComponent with HasGameRef<IslandGame> {
  final UnitModel model;
  late Paint _fillPaint;
  late Paint _borderPaint;
  late Paint _selectedPaint;
  late Paint _targetedPaint; // NEW: Paint for targeting indicator

  // Flag raising component (only for captains)
  FlagRaiseComponent? _flagRaiseComponent;
  bool _isAtApex = false;
  bool _wasAtApex = false;

  // Progress bar component
  ProgressBarComponent? _progressBarComponent;

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

  // Targeting indicator animation
  double _targetingPulse = 0.0;

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
    // NEW: Targeting indicator paint
    _targetedPaint = Paint()
      ..color = Colors.grey.shade400
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

      // Add progress bar above the captain
      _progressBarComponent = ProgressBarComponent(
        unit: model,
        barColor: model.team == Team.blue ? Colors.blue : Colors.red,
        label: 'Progress',
        progress: 0.0,
        verticalOffset: 20.0, // Position it above the flag raising indicator
      );
      add(_progressBarComponent!);
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

    // Remove progress bar if unit dies
    if (_progressBarComponent != null) {
      remove(_progressBarComponent!);
      _progressBarComponent = null;
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
      // Skip rendering if boarded on ship
      if (model.isBoarded) return;

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

      // Always render health bar and indicators (unless playing death animation)
      if (!_isPlayingDeathAnimation) {
        _renderHealthBar(canvas);

        // Render selection indicator
        if (model.isSelected) {
          _renderSelectionIndicator(canvas);
        }

        // NEW: Render targeting indicator
        if (model.isTargeted) {
          _renderTargetingIndicator(canvas);
        }

        // Render flag raising indicator for captains at apex
        if (model.type == UnitType.captain &&
            _isAtApex &&
            !model.hasPlantedFlag) {
          _renderFlagRaiseIndicator(canvas);
        }

        // Render ship seeking indicator
        if (model.isSeekingShip) {
          _renderShipSeekingIndicator(canvas);
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

    // Draw healing effects
    if (_isHealingAnimation) {
      _renderHealingEffect(canvas);
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

  void _renderShipSeekingIndicator(Canvas canvas) {
    // Draw indicator showing unit is seeking ship
    final Paint indicatorPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw pulsing circle
    final double pulseRadius = model.radius +
        4 +
        math.sin(DateTime.now().millisecondsSinceEpoch / 300) * 2;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      pulseRadius,
      indicatorPaint,
    );

    // Draw ship icon or text
    final TextSpan textSpan = TextSpan(
      text: '⚓',
      style: TextStyle(
        color: Colors.green,
        fontSize: 12,
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
        size.y / 2 - model.radius - 20,
      ),
    );
  }

  void _renderHealingEffect(Canvas canvas) {
    // Draw healing sparkles
    final center = Offset(size.x / 2, size.y / 2);
    final paint = Paint()
      ..color = Colors.green.withOpacity(_healingOpacity)
      ..style = PaintingStyle.fill;

    // Draw healing cross
    final crossSize = model.radius * 0.6;
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: crossSize * 0.3,
        height: crossSize,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: crossSize,
        height: crossSize * 0.3,
      ),
      paint,
    );
  }

  void _renderHealthBar(Canvas canvas) {
    final healthPercent = model.health / model.maxHealth;

    // Always show health bar during combat or when damaged
    if (healthPercent < 1.0 || model.isInCombat) {
      // Background
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 8,
            model.radius * 2, 4),
        Paint()..color = Colors.grey.withOpacity(0.7),
      );

      // Health amount
      Color healthColor = healthPercent > 0.6
          ? Colors.green
          : (healthPercent > 0.3 ? Colors.orange : Colors.red);

      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 8,
            model.radius * 2 * healthPercent, 4),
        Paint()..color = healthColor,
      );

      // Health bar border
      canvas.drawRect(
        Rect.fromLTWH(size.x / 2 - model.radius, size.y / 2 - model.radius - 8,
            model.radius * 2, 4),
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      // Show health text during combat
      if (model.isInCombat) {
        final healthText = '${model.health.round()}/${model.maxHealth.round()}';
        final TextSpan textSpan = TextSpan(
          text: healthText,
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
            size.y / 2 - model.radius - 20,
          ),
        );
      }
    }
  }

  void _renderSelectionIndicator(Canvas canvas) {
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      model.radius + 3,
      _selectedPaint,
    );
  }

  // NEW: Render targeting indicator
  void _renderTargetingIndicator(Canvas canvas) {
    // Update pulse animation
    _targetingPulse += 0.1;

    // Create a pulsing grey circle around targeted units
    final double pulseRadius =
        model.radius + 6 + math.sin(_targetingPulse * 2) * 2;
    final double pulseOpacity = 0.6 + math.sin(_targetingPulse * 3) * 0.2;

    // Update paint opacity for pulsing effect
    _targetedPaint.color = Colors.grey.shade400.withOpacity(pulseOpacity);

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      pulseRadius,
      _targetedPaint,
    );

    // Draw crosshairs to make it clear this is a target
    final Paint crosshairPaint = Paint()
      ..color = Colors.grey.shade300.withOpacity(pulseOpacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double crosshairSize = 8;
    final center = Offset(size.x / 2, size.y / 2);

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - crosshairSize, center.dy),
      Offset(center.dx + crosshairSize, center.dy),
      crosshairPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - crosshairSize),
      Offset(center.dx, center.dy + crosshairSize),
      crosshairPaint,
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

      // Remove the old progress bar component since flag component handles it now
      if (_progressBarComponent != null) {
        remove(_progressBarComponent!);
        _progressBarComponent = null;
      }
    }

    // Handle ship boarding logic
    if (model.isSeekingShip && model.targetShipId != null) {
      _updateShipSeeking(dt);
    }

    // Handle healing while boarded
    if (model.isBoarded && model.health < model.maxHealth) {
      model.health =
          math.min(model.health + model.healingRate * dt, model.maxHealth);

      // Play healing animation
      if (!_isHealingAnimation) {
        playHealingAnimation();
      }

      // Disembark when fully healed
      if (model.health >= model.maxHealth) {
        _disembarkFromShip();
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

    // Check if archer should be in attack state and spawn arrows
    if (model.type == UnitType.archer &&
        model.isInCombat &&
        model.targetEnemy != null) {
      try {
        // Update arrow spawn timing
        _timeSinceLastArrow += dt;

        // Spawn arrow when attacking and cooldown is ready
        if (model.state == UnitState.attacking &&
            _timeSinceLastArrow >= _arrowCooldown) {
          _timeSinceLastArrow = 0;

          // Create and add arrow component
          final arrow = ArrowComponent(
            startPosition: position.clone(),
            targetPosition: Vector2(
                model.targetEnemy!.position.x, model.targetEnemy!.position.y),
            team: model.team,
          );

          gameRef.add(arrow);
        }
      } catch (e) {
        // Silently handle any errors in arrow spawning
      }
    } else {
      // Reset arrow timer when not in combat
      _timeSinceLastArrow = _arrowCooldown;
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

    // Update healing animation
    if (_isHealingAnimation) {
      _healingAnimationTimer += dt;
      final progress =
          (_healingAnimationTimer / _healingAnimationDuration).clamp(0.0, 1.0);

      // Pulse healing effect
      _healingOpacity = 0.5 + math.sin(progress * math.pi * 2) * 0.5;

      // Complete animation
      if (_healingAnimationTimer >= _healingAnimationDuration) {
        _isHealingAnimation = false;
        _healingAnimationTimer = 0.0;
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

  void _updateShipSeeking(double dt) {
    // Find the target ship
    final ships = gameRef.getAllShips();
    final targetShip = ships.firstWhere(
      (ship) => ship.model.id == model.targetShipId,
      orElse: () => ships.first, // Fallback, shouldn't happen
    );

    if (targetShip.model.id != model.targetShipId) {
      // Ship not found, stop seeking
      model.targetShipId = null;
      model.isSeekingShip = false;
      return;
    }

    // Check if we're close enough to board
    final distance = position.distanceTo(targetShip.position);
    if (distance < targetShip.model.radius + 20) {
      // Try to board the ship
      if (targetShip.model.canBoardUnit()) {
        targetShip.model.boardUnit(model.id);
        model.boardShip();
        return;
      }
    }

    // Update target position to follow moving ship
    final boardingPos = targetShip.model.getBoardingPosition();
    if (boardingPos != null) {
      model.targetPosition = boardingPos;
      // Don't use regular pathfinding, follow coastline intelligently
      _moveAlongCoastline(dt, boardingPos);
    } else {
      // Ship not at shore, move towards it anyway
      model.targetPosition = targetShip.position.clone();
    }
  }

  void _moveAlongCoastline(double dt, Vector2 target) {
    // Smart movement along coastline
    Vector2 toTarget = target - position;
    double distance = toTarget.length;

    if (distance < 5) {
      model.velocity = Vector2.zero();
      return;
    }

    toTarget.normalize();

    // Check if direct path crosses water
    bool directPathClear = true;
    for (double checkDist = 0; checkDist < distance; checkDist += 10) {
      Vector2 checkPos = position + toTarget * checkDist;
      if (!gameRef.isOnLand(checkPos)) {
        directPathClear = false;
        break;
      }
    }

    if (directPathClear) {
      // Direct path is clear, use it
      model.velocity = toTarget * model.maxSpeed;
    } else {
      // Need to follow coastline
      // Try to move perpendicular to the direct path to find land
      Vector2 perpendicular = Vector2(-toTarget.y, toTarget.x);

      // Try both directions
      for (int i = 0; i < 2; i++) {
        double side = i == 0 ? -1.0 : 1.0;
        Vector2 sideStep = position + perpendicular * side * 20;
        if (gameRef.isOnLand(sideStep)) {
          // Move in this direction
          model.velocity =
              (sideStep - position).normalized() * model.maxSpeed * 0.8;
          break;
        }
      }
    }
  }

  void _disembarkFromShip() {
    if (model.targetShipId == null) return;

    // Find the ship
    final ships = gameRef.getAllShips();
    final ship = ships.firstWhere(
      (s) => s.model.id == model.targetShipId,
      orElse: () => ships.first,
    );

    if (ship.model.id == model.targetShipId) {
      ship.model.disembarkUnit(model.id);

      // Find deployment position
      final deployPos = ship.model.getDeploymentPosition();
      if (deployPos != null) {
        position = deployPos;
        model.position = deployPos;
      }
    }

    model.disembarkShip();
    // Unit becomes visible again (handled in render method)
    _isHealingAnimation = false;
  }

  void setSelected(bool selected) {
    model.isSelected = selected;
  }

  void setTargeted(bool targeted) {
    model.isTargeted = targeted;
  }

  void setTargetPosition(Vector2 target) {
    // Set the exact target position from player input
    model.targetPosition = target.clone();

    // Force the unit to prioritize movement to the new target
    model.forceRedirect = true;

    // Clear any targeted enemy
    model.targetEnemy = null;

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

  /// Set an enemy unit as target
  void setTargetEnemy(UnitModel enemy) {
    // Use the new setTargetEnemy method from UnitModel
    model.setTargetEnemy(enemy, playerInitiated: true);

    // Also set initial target position to enemy position
    model.targetPosition = enemy.position.clone();

    // Force the unit to prioritize this target
    model.forceRedirect = true;

    // Set attacking state if unit can attack
    if (model.attackPower > 0) {
      model.state = UnitState.attacking;
    } else {
      model.state = UnitState.moving;
    }

    // Stop flag raising if captain is ordered to attack
    if (model.type == UnitType.captain && _flagRaiseComponent != null) {
      _flagRaiseComponent!.stopRaisingFlag();
    }
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

    // Add targeting status to info
    String targetingStatus = '';
    if (model.isTargeted) {
      targetingStatus = '\nTARGETED FOR ATTACK';
    }

    // Add ship seeking status
    String shipStatus = '';
    if (model.isSeekingShip) {
      shipStatus = '\nSEEKING SHIP FOR HEALING';
    } else if (model.isBoarded) {
      shipStatus = '\nON SHIP - HEALING';
    }

    // Display unit information using game's notification system
    gameRef.showUnitInfo("Unit: ${typeStr.toUpperCase()}\n"
        "Team: ${teamStr.toUpperCase()}\n"
        "Health: $healthPercent%$flagStatus$targetingStatus$shipStatus");
  }
}
