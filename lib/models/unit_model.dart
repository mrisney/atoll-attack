// lib/models/unit_model.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants/game_config.dart';
import '../rules/combat_rules.dart';
import '../utils/app_logger.dart';

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

  // Ship boarding and healing
  String? targetShipId;
  bool isSeekingShip = false;
  bool isBoarded = false;
  double healingRate = 10.0; // Health per second while on ship
  double lowHealthThreshold = 0.5; // 50% health triggers retreat
  
  // Callback to find ships for boarding
  List<dynamic> Function()? getAllShipsCallback;

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
  double _lastPatrolUpdate = 0.0;
  static const double _patrolUpdateInterval = 5.0; // Update patrol position every 5 seconds

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
    this.getAllShipsCallback,
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
    List<dynamic> Function()? getAllShipsCallback,
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
      getAllShipsCallback: getAllShipsCallback,
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

  void setTargetShip(String shipId) {
    targetShipId = shipId;
    isSeekingShip = true;
    // Clear combat targets when seeking ship
    targetEnemy = null;
    isInCombat = false;
    state = UnitState.moving;
  }

  void boardShip() {
    isBoarded = true;
    isSeekingShip = false;
    state = UnitState.idle;
    velocity = Vector2.zero();
  }

  void disembarkShip() {
    isBoarded = false;
    targetShipId = null;
  }

  bool shouldSeekShip() {
    // Auto-seek ship if health is low and not player-commanded elsewhere
    return health / maxHealth <= lowHealthThreshold &&
        !isInCombat &&
        targetShipId == null &&
        !isSeekingShip; // Don't auto-seek if already seeking
  }

  /// Check if unit should manually seek ship (player-directed)
  bool shouldManuallySeekShip(String shipId) {
    return health < maxHealth && // Any health loss
        !isInCombat &&
        targetShipId == null;
  }

  /// Find the nearest friendly ship for boarding
  String? findNearestFriendlyShip() {
    if (getAllShipsCallback == null) return null;
    
    final ships = getAllShipsCallback!();
    if (ships.isEmpty) return null;
    
    String? nearestShipId;
    double nearestDistance = double.infinity;
    
    for (final ship in ships) {
      // Check if ship is friendly (same team)
      final shipTeam = ship.model?.team;
      if (shipTeam != team) continue;
      
      // Check if ship can accept boarding
      if (!ship.model?.canBoardUnit()) continue;
      
      // Calculate distance
      final shipPosition = ship.model?.position;
      if (shipPosition == null) continue;
      
      final distance = position.distanceTo(shipPosition);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestShipId = ship.model?.id;
      }
    }
    
    return nearestShipId;
  }

  /// Start seeking the nearest friendly ship for healing
  void startSeekingShip() {
    final shipId = findNearestFriendlyShip();
    if (shipId != null) {
      setTargetShip(shipId);
      AppLogger.debug('Unit ${id} seeking ship ${shipId} for healing (health: ${health.toInt()}/${maxHealth.toInt()})');
    }
  }

  /// Manually direct unit to specific ship (player command)
  void seekSpecificShip(String shipId) {
    if (shouldManuallySeekShip(shipId)) {
      setTargetShip(shipId);
      forceRedirect = true; // Override other behaviors
      AppLogger.debug('Unit ${id} manually directed to ship ${shipId} for healing');
    }
  }

  /// Find the target ship object
  dynamic _findTargetShip() {
    if (getAllShipsCallback == null || targetShipId == null) return null;
    
    final ships = getAllShipsCallback!();
    for (final ship in ships) {
      if (ship.model?.id == targetShipId) {
        return ship.model;
      }
    }
    return null;
  }

  /// Process healing while on ship
  void processHealing(double dt) {
    if (!isBoarded) return;
    
    if (health < maxHealth) {
      health += healingRate * dt;
      health = math.min(health, maxHealth);
      
      // Check if fully healed
      if (health >= maxHealth) {
        AppLogger.debug('Unit ${id} fully healed, disembarking ship');
        _disembarkFromShip();
      }
    }
  }

  /// Disembark from ship when healed
  void _disembarkFromShip() {
    if (!isBoarded || targetShipId == null) return;
    
    final targetShip = _findTargetShip();
    if (targetShip != null) {
      // Get disembark position
      final disembarkPosition = targetShip.getBoardingPosition();
      if (disembarkPosition != null) {
        position = disembarkPosition.clone();
        targetPosition = disembarkPosition.clone();
      }
      
      // Remove from ship
      targetShip.disembarkUnit(id);
    }
    
    // Reset boarding state
    disembarkShip();
  }

  /// Get a patrol position around the apex to prevent crowding
  Vector2 _getApexPatrolPosition(Vector2 apexPosition) {
    // Create a patrol position based on unit ID for consistency
    final hash = id.hashCode;
    final angle = (hash % 360) * (math.pi / 180); // Convert to radians
    final patrolRadius = 50.0 + (hash % 30); // 50-80 radius
    
    // Calculate patrol position around apex
    final patrolX = apexPosition.x + math.cos(angle) * patrolRadius;
    final patrolY = apexPosition.y + math.sin(angle) * patrolRadius;
    
    return Vector2(patrolX, patrolY);
  }

  /// Calculate appropriate arrival radius based on target and conditions
  double _calculateArrivalRadius(Vector2 target, Offset? apex) {
    // Base arrival radius
    double arrivalRadius = radius * 2;
    
    // Larger radius for apex area to prevent crowding
    if (apex != null) {
      final apexPosition = Vector2(apex.dx, apex.dy);
      final distanceToApex = target.distanceTo(apexPosition);
      
      if (distanceToApex < 50) {
        // Target is near apex, use larger arrival radius
        arrivalRadius = math.max(arrivalRadius, 25.0);
      }
    }
    
    // Captains need more precise positioning for flag raising
    if (type == UnitType.captain) {
      arrivalRadius = math.min(arrivalRadius, 15.0);
    }
    
    return arrivalRadius;
  }

  /// Calculate alignment force for flocking behavior
  Vector2 _calculateAlignment(List<UnitModel> units) {
    final neighborRadius = 50.0;
    Vector2 averageVelocity = Vector2.zero();
    int neighborCount = 0;

    for (final other in units) {
      if (other.id == id || other.team != team) continue;
      
      final distance = position.distanceTo(other.position);
      if (distance < neighborRadius && distance > 0) {
        averageVelocity += other.velocity;
        neighborCount++;
      }
    }

    if (neighborCount > 0) {
      averageVelocity /= neighborCount.toDouble();
      averageVelocity.normalize();
      averageVelocity.scale(maxSpeed);
      return (averageVelocity - velocity) * 0.1;
    }

    return Vector2.zero();
  }

  /// Calculate cohesion force for flocking behavior
  Vector2 _calculateCohesion(List<UnitModel> units) {
    final neighborRadius = 60.0;
    Vector2 centerOfMass = Vector2.zero();
    int neighborCount = 0;

    for (final other in units) {
      if (other.id == id || other.team != team) continue;
      
      final distance = position.distanceTo(other.position);
      if (distance < neighborRadius) {
        centerOfMass += other.position;
        neighborCount++;
      }
    }

    if (neighborCount > 0) {
      centerOfMass /= neighborCount.toDouble();
      Vector2 toCenterOfMass = centerOfMass - position;
      if (toCenterOfMass.length > 0) {
        toCenterOfMass.normalize();
        toCenterOfMass.scale(maxSpeed);
        return (toCenterOfMass - velocity) * 0.05;
      }
    }

    return Vector2.zero();
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

    // Skip most updates if boarded on ship
    if (isBoarded) {
      // Only handle healing
      processHealing(dt);
      return;
    }

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

    // Check if should auto-seek ship when health is low
    if (shouldSeekShip() && !isSeekingShip) {
      startSeekingShip();
    }

    // Update patrol positions periodically for non-captain units near apex
    if (type != UnitType.captain && apex != null && !isInCombat && !isSeekingShip) {
      _lastPatrolUpdate += dt;
      if (_lastPatrolUpdate >= _patrolUpdateInterval) {
        _lastPatrolUpdate = 0.0;
        
        final apexPosition = Vector2(apex.dx, apex.dy);
        final distanceToApex = position.distanceTo(apexPosition);
        
        // If idle near apex, get a new patrol position
        if (distanceToApex < 100 && state == UnitState.idle && velocity.length < 1.0) {
          targetPosition = _getApexPatrolPosition(apexPosition);
          state = UnitState.moving;
          AppLogger.debug('Unit ${id} updating patrol position near apex');
        }
      }
    }

    // Skip combat if seeking ship for healing
    if (!isSeekingShip && shouldEngageInCombat(units)) {
      processCombat(dt);
      if (isInCombat) {
        return;
      }
    }

    Vector2? moveTarget;

    // Priority 1: Handle ship seeking movement (both auto and manual)
    if (isSeekingShip && targetShipId != null) {
      final targetShip = _findTargetShip();
      if (targetShip != null) {
        final boardingPosition = targetShip.getBoardingPosition();
        if (boardingPosition != null) {
          moveTarget = boardingPosition;
          
          // Check if close enough to board
          final distanceToShip = position.distanceTo(boardingPosition);
          if (distanceToShip <= radius + 10) {
            // Board the ship
            boardShip();
            targetShip.boardUnit(id);
            AppLogger.debug('Unit ${id} boarded ship ${targetShipId}');
            return; // Skip other movement logic
          }
        } else {
          // Ship can't provide boarding position, cancel seeking
          isSeekingShip = false;
          targetShipId = null;
        }
      } else {
        // Target ship not found, cancel seeking
        isSeekingShip = false;
        targetShipId = null;
      }
    }

    // Priority 2: Player-directed movement (forceRedirect or explicit targetPosition)
    if (moveTarget == null && (forceRedirect || targetPosition != position)) {
      moveTarget = targetPosition;
      
      // Check arrival at player-directed target
      double distToTarget = position.distanceTo(targetPosition);
      if (distToTarget < radius * 2) {
        velocity = Vector2.zero();
        state = UnitState.idle;
        if (forceRedirect) {
          forceRedirect = false; // Clear redirect flag
        }
        return;
      }
      
      // Clear forceRedirect after setting target
      if (forceRedirect) {
        state = isSelected ? UnitState.selected : UnitState.moving;
        forceRedirect = false;
      }
    }

    // Priority 3: Combat movement (chase enemies)
    if (moveTarget == null && targetEnemy != null && targetEnemy!.health > 0) {
      double distance = position.distanceTo(targetEnemy!.position);
      if (distance > combatEngagementRange) {
        moveTarget = targetEnemy!.position.clone();
        state = UnitState.moving;
      }
    }

    // Priority 4: Default apex behavior (only if no other targets)
    if (moveTarget == null && apex != null && !(type == UnitType.captain && hasPlantedFlag)) {
      // Only move toward apex if not too close and not crowded
      final apexPosition = Vector2(apex.dx, apex.dy);
      final distanceToApex = position.distanceTo(apexPosition);
      
      // Different behavior for captains vs other units
      if (type == UnitType.captain) {
        // Captains need to reach the apex for flag raising
        moveTarget = apexPosition;
      } else {
        // Other units should patrol around the apex area, not crowd it
        final apexPatrolRadius = 80.0; // Stay within this distance of apex
        final apexAvoidRadius = 30.0;  // Don't get closer than this
        
        if (distanceToApex > apexPatrolRadius) {
          // Too far from apex, move closer
          moveTarget = apexPosition;
        } else if (distanceToApex < apexAvoidRadius) {
          // Too close to apex, move to patrol position
          moveTarget = _getApexPatrolPosition(apexPosition);
        } else {
          // In patrol zone, find a good patrol position
          moveTarget = _getApexPatrolPosition(apexPosition);
        }
      }
    }

    if (moveTarget != null && state != UnitState.raisingFlag && !isInCombat) {
      Vector2 toTarget = moveTarget - position;
      double distToTarget = toTarget.length;

      // Better arrival detection - consider terrain and unit crowding
      final arrivalRadius = _calculateArrivalRadius(moveTarget, apex);
      
      if (distToTarget <= arrivalRadius) {
        // Arrived at target, stop moving
        velocity = Vector2.zero();
        state = UnitState.idle;
        
        // For non-captain units at apex, set a patrol target
        if (apex != null && type != UnitType.captain) {
          final apexPosition = Vector2(apex.dx, apex.dy);
          if (moveTarget.distanceTo(apexPosition) < 50) {
            // Was moving to apex area, now patrol around it
            targetPosition = _getApexPatrolPosition(apexPosition);
          }
        }
      } else if (distToTarget > radius) {
        // Calculate base movement toward target
        toTarget.normalize();
        
        // Add wandering for natural movement
        _wanderAngle += (math.Random().nextDouble() - 0.5) * 0.3;
        double wanderX = math.cos(_wanderAngle) * 0.3;
        double wanderY = math.sin(_wanderAngle) * 0.3;
        toTarget.x += wanderX;
        toTarget.y += wanderY;
        toTarget.normalize();
        
        // Set base velocity
        velocity = toTarget.scaled(maxSpeed);
      }
    }

    // Apply flocking behaviors (separation, alignment, cohesion) for formation
    if (state != UnitState.raisingFlag && !isInCombat && !isSeekingShip) {
      Vector2 separation = _calculateSeparation(units);
      Vector2 alignment = _calculateAlignment(units);
      Vector2 cohesion = _calculateCohesion(units);
      
      // Apply flocking forces with appropriate weights
      applyForce(separation * 2.0);  // Strong separation to avoid crowding
      applyForce(alignment * 0.5);   // Moderate alignment for formation
      applyForce(cohesion * 0.3);    // Light cohesion to stay together
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

      // Only pull toward apex if it's a captain or unit is very far from land
      if (apex != null && (type == UnitType.captain || position.distanceTo(Vector2(apex.dx, apex.dy)) > 100)) {
        Vector2 toApex = Vector2(apex.dx, apex.dy) - position;
        final distanceToApex = toApex.length;
        
        // Reduce apex pull strength based on distance and unit type
        if (distanceToApex > 0) {
          toApex.normalize();
          final pullStrength = type == UnitType.captain ? 0.8 : 0.3;
          velocity += toApex.scaled(maxSpeed * pullStrength);
        }
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

  /// Convert UnitModel to JSON for Firebase sync
  Map<String, dynamic> toJson() {
    return {
      'unitId': id,
      'playerId': playerId,
      'type': type.name,
      'state': state.name,
      'x': position.x,
      'y': position.y,
      'targetX': targetPosition.x,
      'targetY': targetPosition.y,
      'health': health,
      'maxHealth': maxHealth,
      'isSelected': isSelected,
      'team': color == Colors.blue ? 'blue' : 'red',
    };
  }

  /// Create UnitModel from JSON data
  static UnitModel fromJson(Map<String, dynamic> json) {
    final unitType = UnitType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => UnitType.swordsman,
    );
    
    final unitState = UnitState.values.firstWhere(
      (e) => e.name == json['state'],
      orElse: () => UnitState.idle,
    );
    
    final team = json['team'] == 'blue' ? Team.blue : Team.red;
    
    return UnitModel(
      id: json['unitId'] ?? '',
      playerId: json['playerId'] ?? '',
      type: unitType,
      position: Vector2(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      ),
      getAllShipsCallback: null, // Will need to be set separately
    )
      ..state = unitState
      ..targetPosition = Vector2(
        (json['targetX'] as num?)?.toDouble() ?? 0.0,
        (json['targetY'] as num?)?.toDouble() ?? 0.0,
      )
      ..health = (json['health'] as num?)?.toDouble() ?? 100.0
      ..isSelected = json['isSelected'] ?? false;
  }
}
