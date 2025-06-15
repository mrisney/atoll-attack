import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:a_star/a_star.dart';
import '../rules/combat_rules.dart';

enum UnitType {
  captain,
  swordsman,
  archer,
}

enum UnitState {
  idle,
  moving,
  selected,
  attacking,
  gathering,
}

enum Team {
  blue,
  red,
}

class UnitModel {
  final String id;
  final UnitType type;
  UnitState state;
  Vector2 position;
  Vector2 velocity;
  Vector2 targetPosition;
  double maxSpeed;
  double maxForce;
  double mass;
  double radius;
  Color color;
  bool isSelected;
  List<Vector2>? path;

  // Unit stats
  double attackRange;
  double attackPower;
  double defense;
  double health;
  double maxHealth;
  bool hasPlantedFlag = false;
  Team team;

  // Movement tracking and irregularity
  Vector2? _lastValidPosition;
  int _stuckCounter = 0;
  double _lastMovementTime = 0.0;
  double _wanderAngle = 0.0;
  double _noiseOffset = 0.0;

  // Callback to check if position is on land and get terrain info
  bool Function(Vector2)? isOnLandCallback;
  double Function(Vector2)? getTerrainSpeedCallback;

  UnitModel({
    required this.id,
    required this.type,
    required this.position,
    required this.team,
    this.state = UnitState.idle,
    Vector2? velocity,
    Vector2? targetPosition,
    double? maxSpeed,
    double? maxForce,
    double? mass,
    double? radius,
    Color? color,
    this.isSelected = false,
    this.path,
    this.isOnLandCallback,
    this.getTerrainSpeedCallback,
  })  :
        // Set type-specific properties
        attackRange = type == UnitType.archer
            ? 100.0
            : (type == UnitType.swordsman ? 15.0 : 0.0),
        attackPower = type == UnitType.archer
            ? 8.0
            : (type == UnitType.swordsman ? 12.0 : 0.0),
        defense = type == UnitType.swordsman ? 10.0 : 3.0,
        health = type == UnitType.swordsman
            ? 100.0
            : (type == UnitType.captain ? 60.0 : 80.0),
        maxHealth = type == UnitType.swordsman
            ? 100.0
            : (type == UnitType.captain ? 60.0 : 80.0),
        // MUCH SLOWER movement properties for realistic gameplay
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? 25.0 // Slower, more strategic movement
                : (type == UnitType.archer
                    ? 22.0
                    : 20.0)), // Much slower base speeds
        maxForce = maxForce ?? 80.0, // Reduced force for smoother movement
        mass = mass ?? (type == UnitType.swordsman ? 1.5 : 1.0),
        radius = radius ??
            (type == UnitType.swordsman
                ? 8.0
                : (type == UnitType.captain ? 6.0 : 7.0)),
        color = color ??
            (team == Team.blue
                ? (type == UnitType.captain
                    ? Colors.blue.shade700
                    : (type == UnitType.swordsman
                        ? Colors.blue.shade500
                        : Colors.blue.shade300))
                : (type == UnitType.captain
                    ? Colors.red.shade700
                    : (type == UnitType.swordsman
                        ? Colors.red.shade500
                        : Colors.red.shade300))),
        velocity = velocity ?? Vector2.zero(),
        targetPosition = targetPosition ?? position.clone() {
    _lastValidPosition = position.clone();
    _noiseOffset =
        math.Random().nextDouble() * 1000; // Random offset for each unit
  }

  void applyForce(Vector2 force) {
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  bool checkApexReached(Offset? apex) {
    if (type != UnitType.captain || apex == null) return false;

    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance < radius * 3) {
      hasPlantedFlag = true;
      return true;
    }
    return false;
  }

  void update(double dt, List<UnitModel> units, Offset? apex,
      {double? elevationAtPosition}) {
    // Skip update if dead
    if (health <= 0) return;

    _lastMovementTime += dt;

    // Default behavior: move toward apex unless given specific target
    Vector2? primaryTarget;

    if (apex != null && !hasPlantedFlag) {
      Vector2 apexVector = Vector2(apex.dx, apex.dy);

      // If we have a custom target that's significantly different from current position, use it
      if (targetPosition != position) {
        Vector2 toCustomTarget = targetPosition - position;
        double customDistance = toCustomTarget.length;

        // Use custom target if it's close or if it's a significant movement command
        if (customDistance > 10.0) {
          // Only use if it's a meaningful target
          primaryTarget = targetPosition;
        } else {
          primaryTarget = apexVector;
        }
      } else {
        primaryTarget = apexVector;
      }
    }

    // Find nearby enemy units for combat
    final nearbyEnemies = units
        .where((unit) =>
            unit.team != team &&
            unit.health > 0 &&
            position.distanceTo(unit.position) <= attackRange)
        .toList();

    // Combat logic
    if (nearbyEnemies.isNotEmpty && attackPower > 0) {
      state = UnitState.attacking;
      velocity *= 0.7; // More significant slowdown in combat

      final closestEnemy = nearbyEnemies.reduce((a, b) =>
          position.distanceTo(a.position) < position.distanceTo(b.position)
              ? a
              : b);

      final damagePerSecond = attackPower / 2.0;
      closestEnemy.health -= damagePerSecond * dt;

      if (closestEnemy.attackPower > 0) {
        health -= (closestEnemy.attackPower / 2.0) * dt;
      }
    } else {
      state = isSelected ? UnitState.selected : UnitState.moving;
    }

    // Apply very light flocking behaviors
    final friendlyUnits = units
        .where((unit) => unit.team == team && unit.id != id && unit.health > 0)
        .toList();

    if (friendlyUnits.isNotEmpty) {
      Vector2 separation = _separateFromFriendlies(friendlyUnits);
      Vector2 cohesion = _cohesionWithFriendlies(friendlyUnits);
      Vector2 alignment = _alignWithFriendlies(friendlyUnits);

      // Very light flocking forces
      applyForce(separation.scaled(0.3));
      applyForce(cohesion.scaled(0.1));
      applyForce(alignment.scaled(0.05));
    }

    // PRIMARY MOVEMENT: Add irregularity and terrain effects
    if (primaryTarget != null && !hasPlantedFlag) {
      Vector2 toTarget = primaryTarget - position;
      double distToTarget = toTarget.length;

      if (distToTarget > radius) {
        toTarget.normalize();

        // Add wandering behavior for irregular movement
        Vector2 wanderForce = _calculateWanderForce(dt);
        Vector2 targetForce =
            toTarget.scaled(maxSpeed * 0.8); // Reduced target force

        // Combine target seeking with wandering
        Vector2 combinedForce = targetForce + wanderForce;
        applyForce(combinedForce);
      }
    }

    // Apply terrain speed multiplier
    double terrainSpeedMultiplier = 1.0;
    if (getTerrainSpeedCallback != null) {
      terrainSpeedMultiplier = getTerrainSpeedCallback!(position);
    }

    // ANTI-STUCK MECHANISM
    _checkAndHandleStuckState(dt, primaryTarget);

    // Apply terrain-based speed limit
    double effectiveMaxSpeed = maxSpeed * terrainSpeedMultiplier;
    if (velocity.length > effectiveMaxSpeed) {
      velocity.normalize();
      velocity.scale(effectiveMaxSpeed);
    }

    // Apply movement with enhanced land checking
    Vector2 newPosition = position + velocity * dt;

    if (isOnLandCallback != null) {
      if (!isOnLandCallback!(newPosition)) {
        // Try to find a valid direction
        bool foundValidPath = _findValidMovementDirection(dt);

        if (!foundValidPath) {
          // If completely stuck, try moving toward center/upward
          Vector2 escapeDirection = _calculateEscapeDirection(primaryTarget);
          velocity = escapeDirection.scaled(effectiveMaxSpeed * 0.3);
          newPosition = position + velocity * dt;

          // If still invalid, just reduce movement
          if (isOnLandCallback != null && !isOnLandCallback!(newPosition)) {
            velocity *= 0.1;
            newPosition = position + velocity * dt * 0.1;
          }
        } else {
          newPosition = position + velocity * dt;
        }
      } else {
        newPosition = position + velocity * dt;
      }
    }

    // Update position and track movement
    Vector2 actualMovement = newPosition - position;
    if (actualMovement.length > 0.1) {
      _lastValidPosition = position.clone();
      _stuckCounter = 0;
    }

    position = newPosition;

    // Check if captain reached apex
    if (type == UnitType.captain) {
      checkApexReached(apex);
    }

    // Update state
    if (hasPlantedFlag) {
      state = UnitState.idle;
      velocity *= 0.05; // Almost stop when flag is planted

      // Captain sways slightly when flag is planted
      if (type == UnitType.captain) {
        final now = DateTime.now().millisecondsSinceEpoch / 2000;
        Vector2 smallMovement = Vector2(
          math.sin(now) * 0.5,
          math.cos(now) * 0.5,
        );
        Vector2 swayPosition = position + smallMovement * dt;

        if (isOnLandCallback == null || isOnLandCallback!(swayPosition)) {
          position = swayPosition;
        }
      }
    }
  }

  /// Calculate wandering force for irregular movement
  Vector2 _calculateWanderForce(double dt) {
    // Update wander angle with some noise
    _wanderAngle += (math.Random().nextDouble() - 0.5) * 2.0 * dt;

    // Perlin-like noise for smooth irregular movement
    double noiseTime = _lastMovementTime * 0.5 + _noiseOffset;
    double noiseX = math.sin(noiseTime * 1.7) * math.cos(noiseTime * 0.9);
    double noiseY = math.cos(noiseTime * 1.3) * math.sin(noiseTime * 1.1);

    Vector2 wanderDirection = Vector2(
      math.cos(_wanderAngle) + noiseX * 0.3,
      math.sin(_wanderAngle) + noiseY * 0.3,
    );

    wanderDirection.normalize();
    return wanderDirection.scaled(maxSpeed * 0.15); // Light wandering force
  }

  /// Check if unit is stuck and handle it
  void _checkAndHandleStuckState(double dt, Vector2? target) {
    if (_lastMovementTime > 2.0) {
      // Check every 2 seconds
      Vector2 movement = position - (_lastValidPosition ?? position);

      if (movement.length < 3.0) {
        // Barely moved
        _stuckCounter++;

        if (_stuckCounter > 2 && target != null) {
          // Apply unstuck force
          Vector2 unstuckDirection = _calculateEscapeDirection(target);
          Vector2 unstuckForce = unstuckDirection.scaled(maxSpeed);
          applyForce(unstuckForce);

          // Add randomness to break out of local minima
          double randomAngle = math.Random().nextDouble() * 2 * math.pi;
          Vector2 randomForce = Vector2(
            math.cos(randomAngle) * maxSpeed * 0.3,
            math.sin(randomAngle) * maxSpeed * 0.3,
          );
          applyForce(randomForce);
        }
      } else {
        _stuckCounter = 0;
        _lastValidPosition = position.clone();
      }

      _lastMovementTime = 0.0;
    }
  }

  /// Find a valid movement direction when current path is blocked
  bool _findValidMovementDirection(double dt) {
    if (isOnLandCallback == null) return false;

    // Try 8 different directions around the current velocity
    for (int i = 0; i < 8; i++) {
      double angle = (i * math.pi / 4);
      Vector2 rotatedVelocity = Vector2(
        velocity.x * math.cos(angle) - velocity.y * math.sin(angle),
        velocity.x * math.sin(angle) + velocity.y * math.cos(angle),
      );

      Vector2 testPosition = position + rotatedVelocity * dt;

      if (isOnLandCallback!(testPosition)) {
        velocity = rotatedVelocity;
        return true;
      }
    }

    return false;
  }

  /// Calculate direction to escape when stuck
  Vector2 _calculateEscapeDirection(Vector2? target) {
    // If we have a target, try to go around obstacles toward it
    if (target != null) {
      Vector2 toTarget = target - position;
      if (toTarget.length > 0) {
        toTarget.normalize();

        // Try perpendicular directions to go around obstacles
        Vector2 perpendicular1 = Vector2(-toTarget.y, toTarget.x);
        Vector2 perpendicular2 = Vector2(toTarget.y, -toTarget.x);

        // Test which perpendicular direction is better
        if (isOnLandCallback != null) {
          Vector2 test1 = position + perpendicular1 * 15;
          Vector2 test2 = position + perpendicular2 * 15;

          bool valid1 = isOnLandCallback!(test1);
          bool valid2 = isOnLandCallback!(test2);

          if (valid1 && !valid2) return perpendicular1;
          if (valid2 && !valid1) return perpendicular2;
          if (valid1 && valid2) {
            // Choose the one that keeps us closer to target
            double dist1 = (test1 - target).length;
            double dist2 = (test2 - target).length;
            return dist1 < dist2 ? perpendicular1 : perpendicular2;
          }
        }

        return toTarget; // Fallback to direct path
      }
    }

    // Default escape: try to move toward center of map (0,0)
    Vector2 toCenter = Vector2.zero() - position;
    if (toCenter.length > 0) {
      toCenter.normalize();
      return toCenter;
    }

    // Last resort: random direction
    double randomAngle = math.Random().nextDouble() * 2 * math.pi;
    return Vector2(math.cos(randomAngle), math.sin(randomAngle));
  }

  // Much lighter flocking methods
  Vector2 _separateFromFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 steer = Vector2.zero();
    int count = 0;
    final double desiredSeparation = radius * 2.0; // Smaller separation

    for (final other in friendlyUnits) {
      double distance = position.distanceTo(other.position);
      if (distance > 0 && distance < desiredSeparation) {
        Vector2 diff = position - other.position;
        diff.normalize();
        diff.scale(1.0 / distance);
        steer += diff;
        count++;
      }
    }

    if (count > 0) {
      steer.scale(1.0 / count);
      steer.normalize();
      steer.scale(maxSpeed * 0.2); // Much weaker
    }

    return steer;
  }

  Vector2 _cohesionWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 center = Vector2.zero();
    int count = 0;
    final double cohesionRadius = radius * 3; // Smaller radius

    for (final other in friendlyUnits) {
      double distance = position.distanceTo(other.position);
      if (distance > 0 && distance < cohesionRadius) {
        center += other.position;
        count++;
      }
    }

    if (count > 0) {
      center.scale(1.0 / count);
      Vector2 seek = center - position;
      seek.normalize();
      return seek.scaled(maxSpeed * 0.08); // Much weaker
    }

    return Vector2.zero();
  }

  Vector2 _alignWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 avgVelocity = Vector2.zero();
    int count = 0;
    final double alignmentRadius = radius * 2.5; // Smaller radius

    for (final other in friendlyUnits) {
      double distance = position.distanceTo(other.position);
      if (distance > 0 && distance < alignmentRadius) {
        avgVelocity += other.velocity;
        count++;
      }
    }

    if (count > 0) {
      avgVelocity.scale(1.0 / count);
      avgVelocity.normalize();
      return avgVelocity.scaled(maxSpeed * 0.05); // Much weaker
    }

    return Vector2.zero();
  }
}
