import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:a_star/a_star.dart';
import '../rules/combat_rules.dart';

// Import flag raising constants from config
import '../config.dart';

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
  raisingFlag, // New state for captains raising flag
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
  bool forceRedirect = false; // Flag to prioritize player commands over combat

  // Unit stats
  double attackRange;
  double attackPower;
  double defense;
  double health;
  double maxHealth;
  bool hasPlantedFlag = false;
  Team team;
  
  // Combat targeting
  UnitModel? targetEnemy;
  double attackCooldown = 0.0;

  // Flag raising properties (for captains)
  bool isRaisingFlag = false;
  double flagRaiseProgress = 0.0; // 0.0 to 1.0
  double flagRaiseStartTime = 0.0;

  // Callback to check if position is on land
  bool Function(Vector2)? isOnLandCallback;
  double Function(Vector2)? getTerrainSpeedCallback;

  // Movement tracking
  double _noiseOffset = 0.0;
  double _wanderAngle = 0.0;

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
            ? 50.0
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
        // Set movement properties with type-specific defaults from config
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? 5.0
                : (type == UnitType.archer ? 12.0 : 10.0)),
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
        targetPosition = targetPosition ?? position.clone() {
    _noiseOffset = math.Random().nextDouble() * 1000;
  }

  void applyForce(Vector2 force) {
    // F = ma, so a = F/m
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  /// Start flag raising process (for captains only)
  bool startRaisingFlag(Offset? apex) {
    if (type != UnitType.captain ||
        apex == null ||
        hasPlantedFlag ||
        health <= 0) {
      return false;
    }

    // Check if captain is close enough to apex
    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance > kFlagRaiseRange) {
      return false;
    }

    // Check if captain is stationary enough (if required)
    if (kFlagRaiseRequiresStationary &&
        velocity.length > kFlagRaiseStationaryThreshold) {
      return false;
    }

    isRaisingFlag = true;
    state = UnitState.raisingFlag;
    flagRaiseProgress = 0.0;
    flagRaiseStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    return true;
  }

  /// Stop flag raising process
  void stopRaisingFlag() {
    if (isRaisingFlag) {
      isRaisingFlag = false;
      flagRaiseProgress = 0.0;
      state = UnitState.idle;
    }
  }

  /// Update flag raising progress
  void updateFlagRaising(double currentTime) {
    if (!isRaisingFlag || hasPlantedFlag || health <= 0) {
      return;
    }

    double elapsedTime = currentTime - flagRaiseStartTime;
    flagRaiseProgress = (elapsedTime / kFlagRaiseDuration).clamp(0.0, 1.0);

    // Check if flag is fully raised
    if (flagRaiseProgress >= 1.0) {
      hasPlantedFlag = true;
      isRaisingFlag = false;
      state = UnitState.idle;
      // Captain becomes stationary after planting flag
      velocity = Vector2.zero();
    }
  }

  /// Check if captain can raise flag at current position
  bool canRaiseFlagAt(Offset? apex) {
    if (type != UnitType.captain ||
        apex == null ||
        hasPlantedFlag ||
        health <= 0) {
      return false;
    }

    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    if (distance > kFlagRaiseRange) {
      return false;
    }

    if (kFlagRaiseRequiresStationary &&
        velocity.length > kFlagRaiseStationaryThreshold) {
      return false;
    }

    return true;
  }

  // Check if unit has reached the apex (for captain victory condition)
  bool checkApexReached(Offset? apex) {
    if (type != UnitType.captain || apex == null) return false;

    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    return distance < kFlagRaiseRange;
  }

  void update(double dt, List<UnitModel> units, Offset? apex,
      {double? elevationAtPosition}) {
    // Skip update if dead
    if (health <= 0) return;

    double currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Handle flag raising for captains
    if (type == UnitType.captain) {
      if (isRaisingFlag) {
        updateFlagRaising(currentTime);

        // Captain must remain stationary while raising flag
        velocity = Vector2.zero();

        // Stop flag raising if captain takes damage or moves
        if (health <= 0) {
          stopRaisingFlag();
        }

        // Don't process other behaviors while raising flag
        return;
      }

      // Auto-start flag raising if captain reaches apex and stops moving
      if (!hasPlantedFlag && !isRaisingFlag && canRaiseFlagAt(apex)) {
        startRaisingFlag(apex);
        return;
      }
    }

    // Adjust archer range based on elevation
    double effectiveAttackRange = attackRange;
    if (type == UnitType.archer) {
      // If archer is at high elevation (> 0.6), increase range to 100m
      if (elevationAtPosition != null && elevationAtPosition > 0.6) {
        effectiveAttackRange = 100.0;
      }
    }

    // Update attack cooldown
    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }
    
    // Combat logic - check for enemies in range, but only if not being redirected by player
    if (!forceRedirect && state != UnitState.raisingFlag) {
      // If we have a specific target enemy, prioritize it
      if (targetEnemy != null && targetEnemy!.health > 0) {
        double distance = position.distanceTo(targetEnemy!.position);
        
        // If target is in range, attack it
        if (distance <= effectiveAttackRange && attackPower > 0 && attackCooldown <= 0) {
          // Attack enemy
          state = UnitState.attacking;
          targetEnemy!.health -= attackPower * dt * 0.5;
          
          // Set attack cooldown (different for each unit type)
          attackCooldown = type == UnitType.archer ? 0.8 : 0.5;
          
          // Enemy counterattacks if in range
          if (targetEnemy!.attackRange >= distance && targetEnemy!.attackPower > 0) {
            health -= targetEnemy!.attackPower * dt * 0.5;
          }
          
          // Slow down when attacking
          velocity *= 0.8;
        }
        // If target is out of range, move toward it
        else if (distance > effectiveAttackRange && attackPower > 0) {
          // Only update target position if we're not already moving there
          if (targetPosition != targetEnemy!.position) {
            targetPosition = targetEnemy!.position.clone();
          }
        }
      }
      // Otherwise, look for any enemies in range
      else {
        final enemies = units.where((u) => u.team != team && u.health > 0).toList();
        
        // Find closest enemy in range
        UnitModel? closestEnemy;
        double closestDistance = double.infinity;
        
        for (final enemy in enemies) {
          double distance = position.distanceTo(enemy.position);
          if (distance <= effectiveAttackRange && distance < closestDistance) {
            closestEnemy = enemy;
            closestDistance = distance;
          }
        }
        
        // Attack closest enemy if found and cooldown is ready
        if (closestEnemy != null && attackPower > 0 && attackCooldown <= 0) {
          state = UnitState.attacking;
          closestEnemy.health -= attackPower * dt * 0.5;
          
          // Set attack cooldown
          attackCooldown = type == UnitType.archer ? 0.8 : 0.5;
          
          // Enemy counterattacks if in range
          if (closestEnemy.attackRange >= closestDistance && closestEnemy.attackPower > 0) {
            health -= closestEnemy.attackPower * dt * 0.5;
          }
          
          // Slow down when attacking
          velocity *= 0.8;
        }
      }
    } else if (forceRedirect) {
      // If being redirected, prioritize movement
      state = isSelected ? UnitState.selected : UnitState.moving;
      
      // Reset the force redirect flag after a short time to allow normal behavior to resume
      forceRedirect = false;
    }

    // Find allies for flocking
    final allies = units
        .where((u) => u.team == team && u.id != id && u.health > 0)
        .toList();

    // Determine movement target
    Vector2? moveTarget;

    // If unit has a specific target position, prioritize that
    if (targetPosition != position) {
      moveTarget = targetPosition;

      // Check if we're close enough to the target to stop
      double distToTarget = position.distanceTo(targetPosition);
      if (distToTarget < radius * 2) {
        // We've reached the target, stop moving
        velocity = Vector2.zero();
        state = UnitState.idle;
        return; // Skip the rest of the update
      }
    }
    // Otherwise move toward apex if not at flag (and not a captain with flag planted)
    else if (apex != null && !(type == UnitType.captain && hasPlantedFlag)) {
      moveTarget = Vector2(apex.dx, apex.dy);
    }

    // Apply movement forces
    if (moveTarget != null && state != UnitState.raisingFlag) {
      // Direction to target
      Vector2 toTarget = moveTarget - position;
      double distToTarget = toTarget.length;

      if (distToTarget > radius) {
        // Normalize and scale by max speed
        toTarget.normalize();

        // Add some randomness for organic movement
        final rng = math.Random();
        _wanderAngle += (rng.nextDouble() - 0.5) * 0.3;

        // Apply wander force
        double wanderX = math.cos(_wanderAngle) * 0.3;
        double wanderY = math.sin(_wanderAngle) * 0.3;

        // Combine target direction with wander
        toTarget.x += wanderX;
        toTarget.y += wanderY;
        toTarget.normalize();

        // Set velocity directly for more responsive movement
        velocity = toTarget.scaled(maxSpeed);
      }
    }

    // Apply separation from other units (unless raising flag)
    if (state != UnitState.raisingFlag) {
      Vector2 separation = _calculateSeparation(units);
      applyForce(separation);
    }

    // Limit velocity
    if (velocity.length > maxSpeed) {
      velocity.normalize();
      velocity.scale(maxSpeed);
    }

    // Calculate new position
    Vector2 newPosition = position + velocity * dt;

    // Check if new position is on land - with fallback to always allow movement
    bool isOnLand = true;
    if (isOnLandCallback != null) {
      isOnLand = isOnLandCallback!(newPosition);
    }

    // Always allow movement but handle water differently
    if (isOnLand) {
      // Safe to move
      position = newPosition;
    } else {
      // Still move but slower and redirect toward apex
      position = newPosition;
      velocity = velocity * 0.5;

      if (apex != null) {
        Vector2 toApex = Vector2(apex.dx, apex.dy) - position;
        toApex.normalize();
        velocity += toApex.scaled(maxSpeed * 0.8);
      }
    }

    // Update state based on current situation
    if (hasPlantedFlag && type == UnitType.captain) {
      state = UnitState.idle;
      // Captain with planted flag stays mostly still but can sway slightly
      final now = DateTime.now().millisecondsSinceEpoch / 500;
      Vector2 smallMovement = Vector2(
        math.sin(now) * 0.5,
        math.cos(now) * 0.5,
      );
      position += smallMovement * dt;
    } else if (state == UnitState.attacking) {
      // Keep attacking state for a short time but don't stop moving
    } else if (state != UnitState.raisingFlag) {
      state = isSelected ? UnitState.selected : UnitState.moving;
    }
  }

  // Calculate separation force to avoid crowding
  Vector2 _calculateSeparation(List<UnitModel> units) {
    Vector2 steer = Vector2.zero();
    int count = 0;
    double desiredSeparation = radius * 2.5;

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
      steer.scale(maxSpeed * 0.5);
    }

    return steer;
  }
}
