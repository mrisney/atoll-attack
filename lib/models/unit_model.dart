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
                ? 60.0
                : (type == UnitType.archer ? 45.0 : 40.0)),
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

    // Apply flocking behaviors
    if (units.length > 1) {
      // Separation - avoid crowding (weak)
      Vector2 separation = separate(units, desiredSeparation: 20.0);

      // Cohesion - stay with the group (stronger)
      Vector2 cohesion = Vector2.zero();
      if (units.length > 1) {
        Vector2 center = Vector2.zero();
        for (final other in units) {
          if (other.id != id) {
            center += other.position;
          }
        }
        center.scale(1.0 / (units.length - 1));
        Vector2 toCenterForce = center - position;
        toCenterForce.normalize();
        cohesion = toCenterForce.scaled(maxSpeed * 0.5);
      }

      // Apply flocking forces
      applyForce(separation.scaled(0.2)); // Weak separation
      applyForce(cohesion); // Strong cohesion
    }

    // Movement toward apex with minimal randomness
    if (apex != null && !hasPlantedFlag) {
      // Get direction to apex
      Vector2 toApex = Vector2(apex.dx, apex.dy) - position;
      double distToApex = toApex.length;

      if (distToApex > 5.0) {
        toApex.normalize();

        // Add very slight randomness
        final rng = math.Random();
        double randomAngle =
            (rng.nextDouble() - 0.5) * 0.1; // -0.05 to 0.05 radians
        double cos = math.cos(randomAngle);
        double sin = math.sin(randomAngle);
        double newX = toApex.x * cos - toApex.y * sin;
        double newY = toApex.x * sin + toApex.y * cos;
        toApex.x = newX;
        toApex.y = newY;

        // Set strong velocity toward apex
        velocity += toApex.scaled(maxSpeed * 0.8);
      }
    }

    // Ensure units are always moving forward
    if (!hasPlantedFlag) {
      // If velocity is too low, boost it
      if (velocity.length < 10.0) {
        velocity.scale(2.0);
      }

      // Cap maximum velocity
      if (velocity.length > maxSpeed) {
        velocity.normalize();
        velocity.scale(maxSpeed);
      }
    }

    // Apply movement with higher speed - simplified without elevation check here
    Vector2 newPosition = position + velocity * dt * 2.0;
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
        final now = DateTime.now().millisecondsSinceEpoch / 500;
        Vector2 smallMovement = Vector2(
          math.sin(now) * 0.5,
          math.cos(now) * 0.5,
        );
        position += smallMovement * dt;
      }
    } else {
      state = isSelected ? UnitState.selected : UnitState.moving;
    }
  }
}
