// lib/models/unit_model.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants/game_config.dart';
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
  raisingFlag,
}

enum Team {
  blue,
  red,
}

class UnitModel {
  final String id;
  final String playerId;
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
  bool isTargeted;
  List<Vector2>? path;
  bool forceRedirect = false;

  // Unit stats
  double attackRange;
  double attackPower;
  double defense;
  double health;
  double maxHealth;
  bool hasPlantedFlag = false;

  // Computed property for backward compatibility
  Team get team => playerId == 'blue' ? Team.blue : Team.red;

  // Combat targeting and state
  UnitModel? targetEnemy;
  double attackCooldown = 0.0;
  bool isInCombat = false;
  double combatEngagementRange = 25.0;
  bool wasPlayerInitiated = false;

  // Flag raising properties (for captains)
  bool isRaisingFlag = false;
  double flagRaiseProgress = 0.0;
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
    required this.playerId,
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
  })  : // Set type-specific properties
        attackRange = type == UnitType.archer
            ? 60.0
            : (type == UnitType.swordsman ? 20.0 : 15.0),
        attackPower = type == UnitType.archer
            ? 15.0
            : (type == UnitType.swordsman ? 20.0 : 10.0),
        defense = type == UnitType.swordsman ? 15.0 : 5.0,
        health = type == UnitType.swordsman
            ? 120.0
            : (type == UnitType.captain ? 80.0 : 100.0),
        maxHealth = type == UnitType.swordsman
            ? 120.0
            : (type == UnitType.captain ? 80.0 : 100.0),
        // Set movement properties
        maxSpeed = maxSpeed ??
            (type == UnitType.captain
                ? kCaptainSpeed
                : (type == UnitType.archer ? kArcherSpeed : kSwordsmanSpeed)),
        maxForce = maxForce ?? 100.0,
        mass = mass ?? (type == UnitType.swordsman ? 1.5 : 1.0),
        radius = radius ??
            (type == UnitType.swordsman
                ? 8.0
                : (type == UnitType.captain ? 6.0 : 7.0)),
        // Set color based on player
        color = color ?? _getUnitColor(playerId, type),
        velocity = velocity ?? Vector2.zero(),
        targetPosition = targetPosition ?? position.clone() {
    _noiseOffset = math.Random().nextDouble() * 1000;
    _wanderAngle = math.Random().nextDouble() * 2 * math.pi;
  }

  // Factory constructor for backward compatibility
  factory UnitModel.fromTeam({
    required String id,
    required UnitType type,
    required Vector2 position,
    required Team team,
    UnitState state = UnitState.idle,
    Vector2? velocity,
    Vector2? targetPosition,
    double? maxSpeed,
    double? maxForce,
    double? mass,
    double? radius,
    Color? color,
    bool isSelected = false,
    bool isTargeted = false,
    List<Vector2>? path,
    bool Function(Vector2)? isOnLandCallback,
    double Function(Vector2)? getTerrainSpeedCallback,
  }) {
    return UnitModel(
      id: id,
      type: type,
      position: position,
      playerId: team == Team.blue ? 'blue' : 'red',
      state: state,
      velocity: velocity,
      targetPosition: targetPosition,
      maxSpeed: maxSpeed,
      maxForce: maxForce,
      mass: mass,
      radius: radius,
      color: color,
      isSelected: isSelected,
      isTargeted: isTargeted,
      path: path,
      isOnLandCallback: isOnLandCallback,
      getTerrainSpeedCallback: getTerrainSpeedCallback,
    );
  }

  static Color _getUnitColor(String playerId, UnitType type) {
    if (playerId == 'blue') {
      return type == UnitType.captain
          ? Colors.blue.shade700
          : (type == UnitType.swordsman
              ? Colors.blue.shade500
              : Colors.blue.shade300);
    } else {
      return type == UnitType.captain
          ? Colors.red.shade700
          : (type == UnitType.swordsman
              ? Colors.red.shade500
              : Colors.red.shade300);
    }
  }

  void applyForce(Vector2 force) {
    Vector2 acceleration = force.scaled(1.0 / mass);
    velocity += acceleration;
  }

  void setTargetEnemy(UnitModel enemy, {bool playerInitiated = false}) {
    targetEnemy = enemy;
    wasPlayerInitiated = playerInitiated;

    if (playerInitiated &&
        health == maxHealth &&
        enemy.health == enemy.maxHealth) {
      final bonus = type == enemy.type ? 2.0 : 1.0;
      health = math.min(maxHealth + bonus, maxHealth * 1.1);
    }
  }

  bool shouldEngageInCombat(List<UnitModel> allUnits) {
    if (health <= 0 || state == UnitState.raisingFlag) return false;

    if (targetEnemy != null && targetEnemy!.health > 0) {
      if (CombatRules.canAttack(this, targetEnemy!)) {
        double distance = position.distanceTo(targetEnemy!.position);
        double effectiveRange = attackRange;
        if (type == UnitType.archer) {
          effectiveRange = 80.0;
        }
        return distance <= effectiveRange;
      }
    }

    final potentialTargets =
        allUnits.where((u) => u.playerId != playerId && u.health > 0).toList();

    if (potentialTargets.isNotEmpty) {
      final bestTarget = CombatRules.findBestTarget(this, potentialTargets);
      if (bestTarget != null) {
        targetEnemy = bestTarget;
        return true;
      }
    }

    return false;
  }

  void processCombat(double dt) {
    if (targetEnemy == null || targetEnemy!.health <= 0 || health <= 0) {
      isInCombat = false;
      return;
    }

    double distance = position.distanceTo(targetEnemy!.position);
    double effectiveRange = attackRange;
    if (type == UnitType.archer) {
      effectiveRange = 80.0;
    }

    if (!CombatRules.canAttack(this, targetEnemy!) ||
        distance > effectiveRange) {
      if (type != UnitType.archer && distance > combatEngagementRange) {
        targetPosition = targetEnemy!.position.clone();
        isInCombat = false;
        return;
      } else if (type == UnitType.archer) {
        isInCombat = false;
        return;
      }
    }

    isInCombat = true;
    state = UnitState.attacking;

    if (type == UnitType.archer && distance <= effectiveRange) {
      velocity = Vector2.zero();
      targetPosition = position.clone();
    }

    if (attackCooldown > 0) {
      attackCooldown -= dt;
    }

    if (attackCooldown <= 0) {
      double damage = CombatRules.calculateDamage(this, targetEnemy!);
      targetEnemy!.health -= damage;
      targetEnemy!.health = math.max(0, targetEnemy!.health);
      attackCooldown = type == UnitType.archer ? 1.0 : 0.8;

      if (targetEnemy!.health > 0 &&
          CombatRules.canAttack(targetEnemy!, this) &&
          targetEnemy!.attackCooldown <= 0) {
        double counterDamage = CombatRules.calculateDamage(targetEnemy!, this);
        health -= counterDamage;
        health = math.max(0, health);
        targetEnemy!.attackCooldown =
            targetEnemy!.type == UnitType.archer ? 1.0 : 0.8;
      }

      if (health <= 0 || targetEnemy!.health <= 0) {
        isInCombat = false;
        if (targetEnemy!.health <= 0) {
          targetEnemy = null;
        }
      }
    }

    if (type == UnitType.archer) {
      velocity = Vector2.zero();
    } else {
      velocity *= 0.3;
    }
  }

  bool startRaisingFlag(Offset? apex) {
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

    isRaisingFlag = true;
    state = UnitState.raisingFlag;
    flagRaiseProgress = 0.0;
    flagRaiseStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    return true;
  }

  void stopRaisingFlag() {
    if (isRaisingFlag) {
      isRaisingFlag = false;
      flagRaiseProgress = 0.0;
      state = UnitState.idle;
    }
  }

  void updateFlagRaising(double currentTime) {
    if (!isRaisingFlag || hasPlantedFlag || health <= 0) {
      return;
    }

    double elapsedTime = currentTime - flagRaiseStartTime;
    flagRaiseProgress = (elapsedTime / kFlagRaiseDuration).clamp(0.0, 1.0);

    if (flagRaiseProgress >= 1.0) {
      hasPlantedFlag = true;
      isRaisingFlag = false;
      state = UnitState.idle;
      velocity = Vector2.zero();
    }
  }

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

  bool checkApexReached(Offset? apex) {
    if (type != UnitType.captain || apex == null) return false;
    double distance = position.distanceTo(Vector2(apex.dx, apex.dy));
    return distance < kFlagRaiseRange;
  }

  void update(double dt, List<UnitModel> units, Offset? apex,
      {double? elevationAtPosition}) {
    if (health <= 0) return;

    double currentTime = DateTime.now().millisecondsSinceEpoch / 1000.0;

    if (type == UnitType.captain) {
      if (isRaisingFlag) {
        updateFlagRaising(currentTime);
        velocity = Vector2.zero();
        if (health <= 0) {
          stopRaisingFlag();
        }
        return;
      }

      if (!hasPlantedFlag && !isRaisingFlag && canRaiseFlagAt(apex)) {
        startRaisingFlag(apex);
        return;
      }
    }

    if (shouldEngageInCombat(units)) {
      processCombat(dt);
      if (isInCombat) {
        return;
      }
    }

    if (!forceRedirect && targetEnemy != null && targetEnemy!.health > 0) {
      double distance = position.distanceTo(targetEnemy!.position);
      if (distance > combatEngagementRange) {
        targetPosition = targetEnemy!.position.clone();
        state = UnitState.moving;
      }
    } else if (forceRedirect) {
      state = isSelected ? UnitState.selected : UnitState.moving;
      forceRedirect = false;
    }

    Vector2? moveTarget;

    if (targetPosition != position) {
      moveTarget = targetPosition;
      double distToTarget = position.distanceTo(targetPosition);
      if (distToTarget < radius * 2) {
        velocity = Vector2.zero();
        state = UnitState.idle;
        return;
      }
    } else if (apex != null && !(type == UnitType.captain && hasPlantedFlag)) {
      moveTarget = Vector2(apex.dx, apex.dy);
    }

    if (moveTarget != null && state != UnitState.raisingFlag && !isInCombat) {
      Vector2 toTarget = moveTarget - position;
      double distToTarget = toTarget.length;

      if (distToTarget > radius) {
        toTarget.normalize();
        _wanderAngle += (math.Random().nextDouble() - 0.5) * 0.3;
        double wanderX = math.cos(_wanderAngle) * 0.3;
        double wanderY = math.sin(_wanderAngle) * 0.3;
        toTarget.x += wanderX;
        toTarget.y += wanderY;
        toTarget.normalize();
        velocity = toTarget.scaled(maxSpeed);
      }
    }

    if (state != UnitState.raisingFlag && !isInCombat) {
      Vector2 separation = _calculateSeparation(units);
      applyForce(separation);
    }

    if (velocity.length > maxSpeed) {
      velocity.normalize();
      velocity.scale(maxSpeed);
    }

    Vector2 newPosition = position + velocity * dt;

    bool isOnLand = true;
    if (isOnLandCallback != null) {
      isOnLand = isOnLandCallback!(newPosition);
    }

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
        diff.scale(1.0 / distance);
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
