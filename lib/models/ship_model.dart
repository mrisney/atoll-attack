import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';

class ShipModel {
  final String id;
  final Team team;
  Vector2 position;
  Vector2 velocity;
  Vector2? targetPosition;

  // Ship properties
  double maxSpeed = 8.0; // Slower than units
  double radius = 25.0; // Larger than units
  Color color;
  bool isSelected = false;

  // Ship state
  bool isAtShore = false; // Can units disembark
  bool isDeploying = false; // Currently deploying units

  // Ship stats
  double health = 200.0;
  double maxHealth = 200.0;
  int cannonsPerSide = 2;
  double cannonRange = 100.0;
  double cannonPower = 25.0;
  double cannonCooldown = 0.0;

  // Cargo - units that can be deployed
  List<UnitType> cargo = [];
  int maxCargo = 15; // Can carry 15 units initially

  // Movement state
  bool hasSail = true;
  bool usingPaddles = false;
  double sailEfficiency = 1.2; // 20% speed bonus with sail
  double paddleEfficiency = 0.8; // 20% speed penalty with paddles only

  // Callbacks for land detection
  bool Function(Vector2)? isOnLandCallback;
  bool Function(Vector2)? isNearShoreCallback;

  ShipModel({
    required this.id,
    required this.team,
    required this.position,
    Vector2? velocity,
    Vector2? targetPosition,
    this.isOnLandCallback,
    this.isNearShoreCallback,
  })  : velocity = velocity ?? Vector2.zero(),
        targetPosition = targetPosition,
        color = team == Team.blue ? Colors.blue.shade600 : Colors.red.shade600 {
    // Initialize with starting cargo (full complement)
    _initializeCargo();
  }

  /// Initialize ship with starting units
  void _initializeCargo() {
    cargo.clear();

    // Add 1 captain, 7 archers, 7 swordsmen (total 15)
    cargo.add(UnitType.captain);

    for (int i = 0; i < 7; i++) {
      cargo.add(UnitType.archer);
      cargo.add(UnitType.swordsman);
    }
  }

  /// Check if ship can deploy units
  bool canDeployUnits() {
    return isAtShore && cargo.isNotEmpty && health > 0;
  }

  /// Deploy a specific unit type if available
  UnitType? deployUnit(UnitType requestedType) {
    if (!canDeployUnits()) return null;

    // Find and remove the requested unit type from cargo
    for (int i = 0; i < cargo.length; i++) {
      if (cargo[i] == requestedType) {
        return cargo.removeAt(i);
      }
    }

    return null; // Unit type not available
  }

  /// Get available units of each type
  Map<UnitType, int> getAvailableUnits() {
    Map<UnitType, int> available = {
      UnitType.captain: 0,
      UnitType.archer: 0,
      UnitType.swordsman: 0,
    };

    for (final unitType in cargo) {
      available[unitType] = (available[unitType] ?? 0) + 1;
    }

    return available;
  }

  /// Get deployment position near the ship on shore
  Vector2? getDeploymentPosition() {
    if (!isAtShore) return null;

    // Find a position near the ship that's on land
    for (int angle = 0; angle < 360; angle += 30) {
      double rad = angle * math.pi / 180;
      Vector2 deployPos = position +
          Vector2(
            math.cos(rad) * (radius + 10),
            math.sin(rad) * (radius + 10),
          );

      // Check if this position is on land
      if (isOnLandCallback != null && isOnLandCallback!(deployPos)) {
        return deployPos;
      }
    }

    return null; // No valid deployment position found
  }

  /// Update ship state and position
  void update(double dt) {
    if (health <= 0) return;

    // Update cannon cooldown
    if (cannonCooldown > 0) {
      cannonCooldown -= dt;
    }

    // Check shore status
    _updateShoreStatus();

    // Handle movement
    if (targetPosition != null) {
      _updateMovement(dt);
    }
  }

  /// Check if ship is at shore (can deploy units)
  void _updateShoreStatus() {
    if (isNearShoreCallback != null) {
      isAtShore = isNearShoreCallback!(position);
    } else {
      // Fallback: check if any point around the ship is on land
      isAtShore = false;
      for (int angle = 0; angle < 360; angle += 45) {
        double rad = angle * math.pi / 180;
        Vector2 checkPos = position +
            Vector2(
              math.cos(rad) * radius,
              math.sin(rad) * radius,
            );

        if (isOnLandCallback != null && isOnLandCallback!(checkPos)) {
          isAtShore = true;
          break;
        }
      }
    }
  }

  /// Update ship movement
  void _updateMovement(double dt) {
    if (targetPosition == null) return;

    Vector2 direction = targetPosition! - position;
    double distance = direction.length;

    if (distance < radius) {
      // Reached target
      velocity = Vector2.zero();
      targetPosition = null;
      return;
    }

    // Normalize direction
    direction.normalize();

    // Calculate effective speed based on propulsion
    double effectiveSpeed = maxSpeed;
    if (hasSail && !usingPaddles) {
      effectiveSpeed *= sailEfficiency;
    } else if (usingPaddles) {
      effectiveSpeed *= paddleEfficiency;
    }

    // Set velocity
    velocity = direction.scaled(effectiveSpeed);

    // Update position
    position += velocity * dt;
  }

  /// Fire cannons at target (if in range)
  bool fireCannsAt(Vector2 target) {
    if (cannonCooldown > 0 || health <= 0) return false;

    double distance = position.distanceTo(target);
    if (distance > cannonRange) return false;

    // Fire cannons
    cannonCooldown = 3.0; // 3 second cooldown
    return true;
  }

  /// Take damage
  void takeDamage(double damage) {
    health -= damage;
    health = math.max(0, health);
  }

  /// Repair ship (when at friendly shore)
  void repair(double amount) {
    if (isAtShore) {
      health += amount;
      health = math.min(maxHealth, health);
    }
  }

  /// Set target position for movement
  void setTargetPosition(Vector2 target) {
    targetPosition = target.clone();
  }

  /// Stop movement
  void stop() {
    targetPosition = null;
    velocity = Vector2.zero();
  }

  /// Get ship status for UI
  String getStatusText() {
    if (health <= 0) return "DESTROYED";
    if (isAtShore) return "AT SHORE - CAN DEPLOY";
    if (targetPosition != null) return "MOVING";
    return "AT SEA";
  }

  /// Get health percentage
  double get healthPercent => health / maxHealth;

  /// Get cargo count
  int get cargoCount => cargo.length;

  /// Check if ship is destroyed
  bool get isDestroyed => health <= 0;
}
