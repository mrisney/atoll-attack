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
  double maxHealth; // Added for health bar calculations
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
        // Set movement properties with type-specific defaults
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? 30.0 // Reduced from 60.0
                : (type == UnitType.archer ? 25.0 : 20.0)), // Reduced speeds
        maxForce = maxForce ?? 100.0,
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

  // Simple flocking behaviors
  Vector2 separate(List<UnitModel> units,
      {double desiredSeparation = 25.0, double weight = 1.5}) {
    Vector2 steer = Vector2.zero();
    int count = 0;

    for (final other in units) {
      if (other.id == id) continue;

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
      steer.scale(maxSpeed);
    }

    return steer.scaled(weight);
  }

  void applyForce(Vector2 force) {
    // F = ma, so a = F/m
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  // Check if unit has reached the apex (for captain victory condition)
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

      // Stop moving toward apex when in combat
      velocity *= 0.5; // Slow down dramatically in combat

      // Attack the closest enemy
      final closestEnemy = nearbyEnemies.reduce((a, b) =>
          position.distanceTo(a.position) < position.distanceTo(b.position)
              ? a
              : b);

      // Simple combat - deal damage over time
      final damagePerSecond = attackPower / 2.0; // Spread damage over time
      closestEnemy.health -= damagePerSecond * dt;

      // Take counter-damage if enemy can fight back
      if (closestEnemy.attackPower > 0) {
        health -= (closestEnemy.attackPower / 2.0) * dt;
      }

      // Don't move toward apex while fighting
      return;
    } else {
      // Not in combat, can move toward apex
      state = isSelected ? UnitState.selected : UnitState.moving;
    }

    // Apply flocking behaviors only with friendly units
    final friendlyUnits = units
        .where((unit) => unit.team == team && unit.id != id && unit.health > 0)
        .toList();

    if (friendlyUnits.isNotEmpty) {
      // Separation - avoid crowding (stronger)
      Vector2 separation = _separateFromFriendlies(friendlyUnits);

      // Cohesion - stay with the group (moderate)
      Vector2 cohesion = _cohesionWithFriendlies(friendlyUnits);

      // Alignment - move in same direction as group (weak)
      Vector2 alignment = _alignWithFriendlies(friendlyUnits);

      // Apply flocking forces with appropriate weights
      applyForce(separation.scaled(1.5)); // Strong separation
      applyForce(cohesion.scaled(0.8)); // Moderate cohesion
      applyForce(alignment.scaled(0.3)); // Weak alignment
    }

    // Movement toward apex (only when not fighting)
    if (apex != null && !hasPlantedFlag) {
      Vector2 toApex = Vector2(apex.dx, apex.dy) - position;
      double distToApex = toApex.length;

      if (distToApex > 8.0) {
        // Increased threshold
        toApex.normalize();

        // Much weaker force toward apex to allow flocking
        velocity += toApex.scaled(maxSpeed * 0.3); // Reduced from 0.8 to 0.3
      }
    }

    // Much slower movement
    if (!hasPlantedFlag) {
      // Lower minimum velocity
      if (velocity.length < 5.0) {
        // Reduced from 10.0
        velocity.normalize();
        velocity.scale(5.0);
      }

      // Lower maximum velocity
      if (velocity.length > maxSpeed * 0.6) {
        // Cap at 60% of max speed
        velocity.normalize();
        velocity.scale(maxSpeed * 0.6);
      }
    }

    // Calculate potential new position
    Vector2 newPosition =
        position + velocity * dt * 0.8; // Reduced from 2.0 to 0.8

    // Check if new position would be on land - if not, adjust
    if (isOnLandCallback != null) {
      if (!isOnLandCallback!(newPosition)) {
        // Try to find a valid position by reducing movement
        Vector2 reducedVelocity = velocity * 0.5;
        Vector2 testPosition = position + reducedVelocity * dt * 0.8;

        // If reduced movement is still invalid, stop movement
        if (!isOnLandCallback!(testPosition)) {
          velocity *= 0.1; // Almost stop
          newPosition = position + velocity * dt * 0.1;

          // Final check - if still invalid, don't move
          if (!isOnLandCallback!(newPosition)) {
            newPosition = position;
            velocity = Vector2.zero();
          }
        } else {
          newPosition = testPosition;
          velocity = reducedVelocity;
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
        final now = DateTime.now().millisecondsSinceEpoch / 1000; // Slower sway
        Vector2 smallMovement = Vector2(
          math.sin(now) * 0.2, // Reduced movement
          math.cos(now) * 0.2,
        );
        Vector2 swayPosition = position + smallMovement * dt;

        // Only apply sway if it keeps captain on land
        if (isOnLandCallback == null || isOnLandCallback!(swayPosition)) {
          position = swayPosition;
        }
      }
    }
  }

  // Helper methods for improved flocking
  Vector2 _separateFromFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 steer = Vector2.zero();
    int count = 0;
    final double desiredSeparation = radius * 4; // Maintain distance

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
      steer.scale(maxSpeed);
    }

    return steer;
  }

  Vector2 _cohesionWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 center = Vector2.zero();
    int count = 0;
    final double cohesionRadius = radius * 8; // Look for friends in larger area

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
      return seek.scaled(maxSpeed * 0.5);
    }

    return Vector2.zero();
  }

  Vector2 _alignWithFriendlies(List<UnitModel> friendlyUnits) {
    Vector2 avgVelocity = Vector2.zero();
    int count = 0;
    final double alignmentRadius = radius * 6;

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
      return avgVelocity.scaled(maxSpeed * 0.4);
    }

    return Vector2.zero();
  }
}
