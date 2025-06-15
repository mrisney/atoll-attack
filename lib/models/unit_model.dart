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
        // SIGNIFICANTLY INCREASED movement properties
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? 50.0 // Much faster captain
                : (type == UnitType.archer
                    ? 45.0
                    : 40.0)), // Much faster all units
        maxForce = maxForce ?? 200.0, // Much higher force
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
        targetPosition = targetPosition ?? position.clone();

  void applyForce(Vector2 force) {
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  bool checkApexReached(Offset? apex) {
    if (type != UnitType.captain || apex == null) return false;

    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance < radius * 2) {
      hasPlantedFlag = true;
      return true;
    }
    return false;
  }

  void update(double dt, List<UnitModel> units, Offset? apex,
      {double? elevationAtPosition}) {
    // Skip update if dead
    if (health <= 0) return;

    // Find nearby enemy units for combat
    final nearbyEnemies = units
        .where((unit) =>
            unit.team != team &&
            unit.health > 0 &&
            position.distanceTo(unit.position) <= attackRange)
        .toList();

    // Combat logic - if enemies are in range, engage them
    if (nearbyEnemies.isNotEmpty && attackPower > 0) {
      state = UnitState.attacking;

      // Much less slowdown in combat - keep moving!
      velocity *= 0.9; // Was 0.7, now 0.9

      // Attack the closest enemy
      final closestEnemy = nearbyEnemies.reduce((a, b) =>
          position.distanceTo(a.position) < position.distanceTo(b.position)
              ? a
              : b);

      // Simple combat - deal damage over time
      final damagePerSecond = attackPower / 2.0;
      closestEnemy.health -= damagePerSecond * dt;

      // Take counter-damage if enemy can fight back
      if (closestEnemy.attackPower > 0) {
        health -= (closestEnemy.attackPower / 2.0) * dt;
      }

      // Still allow movement toward target during combat
    } else {
      // Not in combat, can move normally
      state = isSelected ? UnitState.selected : UnitState.moving;
    }

    // Apply flocking behaviors with friendly units but MUCH WEAKER
    final friendlyUnits = units
        .where((unit) => unit.team == team && unit.id != id && unit.health > 0)
        .toList();

    if (friendlyUnits.isNotEmpty) {
      // Much weaker flocking to avoid getting stuck
      Vector2 separation = _separateFromFriendlies(friendlyUnits);
      Vector2 cohesion = _cohesionWithFriendlies(friendlyUnits);
      Vector2 alignment = _alignWithFriendlies(friendlyUnits);

      // Much weaker flocking forces
      applyForce(separation.scaled(0.3)); // Much weaker
      applyForce(cohesion.scaled(0.1)); // Much weaker
      applyForce(alignment.scaled(0.05)); // Much weaker
    }

    // PRIORITIZE movement toward target
    Vector2? targetToUse;

    // Check if we have a custom target (player-directed movement)
    if (targetPosition != position) {
      final distanceToCustomTarget = position.distanceTo(targetPosition);

      if (apex != null) {
        final apexVector = Vector2(apex.dx, apex.dy);
        final distanceToApex = position.distanceTo(apexVector);

        // Use custom target if it's significantly different from apex
        if (distanceToCustomTarget < distanceToApex ||
            targetPosition.distanceTo(apexVector) > 50) {
          targetToUse = targetPosition;
        } else {
          targetToUse = apexVector;
        }
      } else {
        targetToUse = targetPosition;
      }
    } else if (apex != null && !hasPlantedFlag) {
      targetToUse = Vector2(apex.dx, apex.dy);
    }

    if (targetToUse != null) {
      Vector2 toTarget = targetToUse - position;
      double distToTarget = toTarget.length;

      if (distToTarget > radius * 2) {
        // Move towards target
        toTarget.normalize();

        // MUCH STRONGER force toward target
        velocity += toTarget.scaled(maxSpeed * 1.2); // Much stronger targeting
      }
    }

    // MUCH more aggressive movement
    if (!hasPlantedFlag) {
      // Higher minimum velocity to prevent getting stuck
      if (velocity.length < 15.0) {
        // Much higher minimum
        if (targetToUse != null) {
          Vector2 toTarget = targetToUse - position;
          if (toTarget.length > radius) {
            toTarget.normalize();
            velocity = toTarget.scaled(15.0); // Force movement
          }
        }
      }

      // Higher maximum velocity
      if (velocity.length > maxSpeed * 1.5) {
        // Allow exceeding max speed
        velocity.normalize();
        velocity.scale(maxSpeed * 1.5);
      }
    }

    // MUCH more aggressive position update
    Vector2 newPosition =
        position + velocity * dt * 2.0; // Double movement speed

    // Improved land checking with better fallback
    if (isOnLandCallback != null) {
      if (!isOnLandCallback!(newPosition)) {
        // Try multiple directions to find valid path
        bool foundValidDirection = false;

        // Try 16 different directions
        for (int i = 0; i < 16; i++) {
          double angle = (i * math.pi / 8);
          Vector2 rotatedVelocity = Vector2(
            velocity.x * math.cos(angle) - velocity.y * math.sin(angle),
            velocity.x * math.sin(angle) + velocity.y * math.cos(angle),
          );

          Vector2 testPosition = position + rotatedVelocity * dt * 2.0;

          if (isOnLandCallback!(testPosition)) {
            newPosition = testPosition;
            velocity = rotatedVelocity;
            foundValidDirection = true;
            break;
          }
        }

        // If no valid direction found, try moving toward center of island
        if (!foundValidDirection) {
          Vector2 toCenter =
              Vector2.zero() - position; // Assume center is at origin
          if (toCenter.length > 0) {
            toCenter.normalize();
            Vector2 centerDirection = toCenter.scaled(velocity.length * 0.5);
            Vector2 testPosition = position + centerDirection * dt * 2.0;

            if (isOnLandCallback!(testPosition)) {
              newPosition = testPosition;
              velocity = centerDirection;
            } else {
              // Last resort: minimal movement
              velocity *= 0.1;
              newPosition = position + velocity * dt * 0.2;
            }
          }
        }
      }
    }

    position = newPosition;

    // Check if captain reached apex
    if (type == UnitType.captain) {
      checkApexReached(apex);
    }

    // Update state
    if (hasPlantedFlag) {
      state = UnitState.idle;
      velocity = Vector2.zero();

      // Captain sways slightly when flag is planted
      if (type == UnitType.captain) {
        final now = DateTime.now().millisecondsSinceEpoch / 2000;
        Vector2 smallMovement = Vector2(
          math.sin(now) * 0.3,
          math.cos(now) * 0.3,
        );
        Vector2 swayPosition = position + smallMovement * dt;

        if (isOnLandCallback == null || isOnLandCallback!(swayPosition)) {
          position = swayPosition;
        }
      }
    }
  }

  // Much weaker flocking methods to prevent getting stuck
  Vector2 _separateFromFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 steer = Vector2.zero();
    int count = 0;
    final double desiredSeparation = radius * 2; // Smaller separation distance

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
      steer.scale(maxSpeed * 0.3); // Much weaker
    }

    return steer;
  }

  Vector2 _cohesionWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 center = Vector2.zero();
    int count = 0;
    final double cohesionRadius = radius * 4; // Smaller radius

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
      return seek.scaled(maxSpeed * 0.2); // Much weaker
    }

    return Vector2.zero();
  }

  Vector2 _alignWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 avgVelocity = Vector2.zero();
    int count = 0;
    final double alignmentRadius = radius * 3; // Smaller radius

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
      return avgVelocity.scaled(maxSpeed * 0.1); // Much weaker
    }

    return Vector2.zero();
  }
}
