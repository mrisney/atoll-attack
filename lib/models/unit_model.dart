import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

// Import flag raising constants from config
import '../constants/game_config.dart';
import '../rules/combat_rules.dart'; // Use existing combat rules

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
  bool isTargeted; // Track if this unit is targeted for attack
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

  // Combat targeting and state
  UnitModel? targetEnemy;
  double attackCooldown = 0.0;
  bool isInCombat = false;
  double combatEngagementRange = 25.0; // Range to start combat
  bool wasPlayerInitiated = false; // Track if this attack was player-initiated

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
    this.isTargeted = false,
    this.path,
    this.isOnLandCallback,
    this.getTerrainSpeedCallback,
  })  :
        // Set type-specific properties with enhanced combat stats
        attackRange = type == UnitType.archer
            ? 60.0 // Increased archer range
            : (type == UnitType.swordsman
                ? 20.0
                : 15.0), // Increased melee range
        attackPower = type == UnitType.archer
            ? 15.0 // Increased archer damage
            : (type == UnitType.swordsman
                ? 20.0
                : 10.0), // Increased swordsman damage
        defense = type == UnitType.swordsman
            ? 15.0
            : 5.0, // Increased swordsman defense
        health = type == UnitType.swordsman
            ? 120.0 // Increased swordsman health
            : (type == UnitType.captain
                ? 80.0
                : 100.0), // Increased archer health
        maxHealth = type == UnitType.swordsman
            ? 120.0
            : (type == UnitType.captain ? 80.0 : 100.0),
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

  /// Set a target enemy and initiate combat using CombatRules
  void setTargetEnemy(UnitModel enemy, {bool playerInitiated = false}) {
    targetEnemy = enemy;
    wasPlayerInitiated = playerInitiated;

    // Give slight advantage to player-initiated attacks
    if (playerInitiated &&
        health == maxHealth &&
        enemy.health == enemy.maxHealth) {
      // Add 1-2 points of health advantage for initiating attack
      final bonus = type == enemy.type ? 2.0 : 1.0;
      health = math.min(
          maxHealth + bonus, maxHealth * 1.1); // Cap at 110% max health
    }
  }

  /// Check if unit should engage in combat using CombatRules
  bool shouldEngageInCombat(List<UnitModel> allUnits) {
    if (health <= 0 || state == UnitState.raisingFlag) return false;

    // If we have a specific target enemy, check if we can attack it
    if (targetEnemy != null && targetEnemy!.health > 0) {
      if (CombatRules.canAttack(this, targetEnemy!)) {
        double distance = position.distanceTo(targetEnemy!.position);

        // For archers, check if they have high ground advantage for extended range
        double effectiveRange = attackRange;
        if (type == UnitType.archer) {
          // Assume we can get elevation somehow - for now use a simple distance check
          // In real implementation, this would use elevationAtPosition
          effectiveRange = 80.0; // Extended range for archers on high ground
        }

        // Engage if within effective range
        return distance <= effectiveRange;
      }
    }

    // Look for nearby enemies if no specific target
    final potentialTargets =
        allUnits.where((u) => u.team != team && u.health > 0).toList();

    if (potentialTargets.isNotEmpty) {
      // Use CombatRules to find the best target
      final bestTarget = CombatRules.findBestTarget(this, potentialTargets);
      if (bestTarget != null) {
        targetEnemy = bestTarget;
        return true;
      }
    }

    return false;
  }

  /// Process combat between this unit and target enemy using CombatRules
  void processCombat(double dt) {
    if (targetEnemy == null || targetEnemy!.health <= 0 || health <= 0) {
      isInCombat = false;
      return;
    }

    double distance = position.distanceTo(targetEnemy!.position);

    // Calculate effective range based on unit type and position
    double effectiveRange = attackRange;
    if (type == UnitType.archer) {
      // Archers get extended range (simulate high ground advantage)
      effectiveRange = 80.0;
    }

    // Check if we can attack using CombatRules
    if (!CombatRules.canAttack(this, targetEnemy!) ||
        distance > effectiveRange) {
      // If enemy is too far, move toward them (but only for melee units)
      if (type != UnitType.archer && distance > combatEngagementRange) {
        targetPosition = targetEnemy!.position.clone();
        isInCombat = false;
        return;
      }
      // Archers stay in position if target is out of range
      else if (type == UnitType.archer) {
        isInCombat = false;
        return;
      }
    }

    // We're in combat range and can attack
    isInCombat = true;
    state = UnitState.attacking;

    // IMPORTANT: Archers should NOT move toward target when in range
    if (type == UnitType.archer && distance <= effectiveRange) {
      // Stop moving - archer is in position to fire
      velocity = Vector2.zero();
      targetPosition = position.clone(); // Stay in current position
    }

    // Reduce cooldown
    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }

    // Attack if cooldown is ready
    if (attackCooldown <= 0) {
      // Use CombatRules to calculate damage
      double damage = CombatRules.calculateDamage(this, targetEnemy!);

      // Apply damage
      targetEnemy!.health -= damage;
      targetEnemy!.health = math.max(0, targetEnemy!.health);

      // Set attack cooldown based on unit type
      attackCooldown = type == UnitType.archer ? 1.0 : 0.8;

      // Counter-attack if enemy is alive and can attack back
      if (targetEnemy!.health > 0 &&
          CombatRules.canAttack(targetEnemy!, this) &&
          targetEnemy!.attackCooldown <= 0) {
        double counterDamage = CombatRules.calculateDamage(targetEnemy!, this);
        health -= counterDamage;
        health = math.max(0, health);
        targetEnemy!.attackCooldown =
            targetEnemy!.type == UnitType.archer ? 1.0 : 0.8;
      }

      // Stop combat if either unit dies
      if (health <= 0 || targetEnemy!.health <= 0) {
        isInCombat = false;
        if (targetEnemy!.health <= 0) {
          targetEnemy = null; // Clear dead target
        }
      }
    }

    // Movement behavior during combat
    if (type == UnitType.archer) {
      // Archers stay still when attacking
      velocity = Vector2.zero();
    } else {
      // Melee units slow down during combat but can still move slightly
      velocity *= 0.3;
    }
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

    // PRIORITY 1: Process combat if engaged or should engage
    if (shouldEngageInCombat(units)) {
      processCombat(dt);
      if (isInCombat) {
        return; // Don't process other behaviors during active combat
      }
    }

    // PRIORITY 2: Handle player-directed targeting
    if (!forceRedirect && targetEnemy != null && targetEnemy!.health > 0) {
      double distance = position.distanceTo(targetEnemy!.position);

      // Move toward target if not in combat range
      if (distance > combatEngagementRange) {
        targetPosition = targetEnemy!.position.clone();
        state = UnitState.moving;
      }
    } else if (forceRedirect) {
      // If being redirected by player, prioritize movement
      state = isSelected ? UnitState.selected : UnitState.moving;
      forceRedirect = false;
    }

    // PRIORITY 3: Normal movement and behavior
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
        return;
      }
    }
    // Otherwise move toward apex if not at flag (and not a captain with flag planted)
    else if (apex != null && !(type == UnitType.captain && hasPlantedFlag)) {
      moveTarget = Vector2(apex.dx, apex.dy);
    }

    // Apply movement forces
    if (moveTarget != null && state != UnitState.raisingFlag && !isInCombat) {
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

    // Apply separation from other units (unless raising flag or in combat)
    if (state != UnitState.raisingFlag && !isInCombat) {
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

    // Check if new position is on land
    bool isOnLand = true;
    if (isOnLandCallback != null) {
      isOnLand = isOnLandCallback!(newPosition);
    }

    // Always allow movement but handle water differently
    if (isOnLand) {
      position = newPosition;
    } else {
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
      final now = DateTime.now().millisecondsSinceEpoch / 500;
      Vector2 smallMovement = Vector2(
        math.sin(now) * 0.5,
        math.cos(now) * 0.5,
      );
      position += smallMovement * dt;
    } else if (state != UnitState.raisingFlag && !isInCombat) {
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
