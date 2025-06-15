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

  // Movement tracking
  Vector2? _lastValidPosition;
  int _stuckCounter = 0;
  double _lastMovementTime = 0.0;

  // Callback to check if position is on land
  bool Function(Vector2)? isOnLandCallback;

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
        // Enhanced movement properties for better pathfinding
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? 60.0 // Fast captain for flag planting
                : (type == UnitType.archer
                    ? 50.0
                    : 45.0)), // Good movement speeds
        maxForce = maxForce ?? 300.0, // Higher force for better movement
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
  }

  void applyForce(Vector2 force) {
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  bool checkApexReached(Offset? apex) {
    if (type != UnitType.captain || apex == null) return false;

    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance < radius * 3) {
      // Slightly larger reach for apex
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

      // If we have a custom target, use it temporarily, but bias toward apex
      if (targetPosition != position) {
        Vector2 toCustomTarget = targetPosition - position;
        Vector2 toApex = apexVector - position;

        // If custom target is roughly in the direction of apex, use it
        // Otherwise, prioritize apex
        double customDistance = toCustomTarget.length;
        double apexDistance = toApex.length;

        if (customDistance < 100 || customDistance < apexDistance * 0.5) {
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
      velocity *= 0.85; // Slight slowdown in combat

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

    // Apply light flocking behaviors
    final friendlyUnits = units
        .where((unit) => unit.team == team && unit.id != id && unit.health > 0)
        .toList();

    if (friendlyUnits.isNotEmpty) {
      Vector2 separation = _separateFromFriendlies(friendlyUnits);
      Vector2 cohesion = _cohesionWithFriendlies(friendlyUnits);
      Vector2 alignment = _alignWithFriendlies(friendlyUnits);

      // Light flocking forces
      applyForce(separation.scaled(0.5));
      applyForce(cohesion.scaled(0.2));
      applyForce(alignment.scaled(0.1));
    }

    // PRIMARY MOVEMENT: Strong force toward target
    if (primaryTarget != null && !hasPlantedFlag) {
      Vector2 toTarget = primaryTarget - position;
      double distToTarget = toTarget.length;

      if (distToTarget > radius) {
        toTarget.normalize();

        // Very strong targeting force
        Vector2 targetForce = toTarget.scaled(maxSpeed * 2.0);
        applyForce(targetForce);
      }
    }

    // ANTI-STUCK MECHANISM
    _checkAndHandleStuckState(dt, primaryTarget);

    // Limit velocity
    if (velocity.length > maxSpeed) {
      velocity.normalize();
      velocity.scale(maxSpeed);
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
          velocity = escapeDirection.scaled(maxSpeed * 0.5);
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
      velocity *= 0.1; // Almost stop when flag is planted

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

  /// Check if unit is stuck and handle it
  void _checkAndHandleStuckState(double dt, Vector2? target) {
    if (_lastMovementTime > 1.0) {
      // Check every second
      Vector2 movement = position - (_lastValidPosition ?? position);

      if (movement.length < 5.0) {
        // Barely moved
        _stuckCounter++;

        if (_stuckCounter > 3 && target != null) {
          // Apply unstuck force
          Vector2 unstuckDirection = _calculateEscapeDirection(target);
          Vector2 unstuckForce = unstuckDirection.scaled(maxSpeed * 1.5);
          applyForce(unstuckForce);

          // Add some randomness to break out of local minima
          double randomAngle = math.Random().nextDouble() * 2 * math.pi;
          Vector2 randomForce = Vector2(
            math.cos(randomAngle) * maxSpeed * 0.5,
            math.sin(randomAngle) * maxSpeed * 0.5,
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

    // Try 16 different directions around the current velocity
    for (int i = 0; i < 16; i++) {
      double angle = (i * math.pi / 8);
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
          Vector2 test1 = position + perpendicular1 * 20;
          Vector2 test2 = position + perpendicular2 * 20;

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

  // Lightweight flocking methods
  Vector2 _separateFromFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 steer = Vector2.zero();
    int count = 0;
    final double desiredSeparation = radius * 2.5;

    for (final other in friendlyUnits) {
      double distance = position.distanceTo(other.position);
      if (distance > 0 && distance < desiredSeparation) {
        Vector2 diff = position - other.position;
        diff.normalize();
        diff.scale(1.0 / distance); // Weight by distance
        steer += diff;
        count++;
      }
    }

    if (count > 0) {
      steer.scale(1.0 / count);
      steer.normalize();
      steer.scale(maxSpeed * 0.4);
    }

    return steer;
  }

  Vector2 _cohesionWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 center = Vector2.zero();
    int count = 0;
    final double cohesionRadius = radius * 5;

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
      return seek.scaled(maxSpeed * 0.15);
    }

    return Vector2.zero();
  }

  Vector2 _alignWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 avgVelocity = Vector2.zero();
    int count = 0;
    final double alignmentRadius = radius * 4;

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
      return avgVelocity.scaled(maxSpeed * 0.1);
    }

    return Vector2.zero();
  }
}
