// lib/game/ship_model.dart - Ship model with pathfinding and collision detection

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
  List<Vector2>? navigationPath; // Waypoint path around obstacles

  // Ship properties
  double maxSpeed = 8.0;
  double radius = 25.0;
  Color color;
  bool isSelected = false;

  // Ship state
  bool isAtShore = false;
  bool isDeploying = false;
  bool isStuck = false;
  bool isNavigating = false; // Following a path around obstacles

  // Ship stats
  double health = 200.0;
  double maxHealth = 200.0;
  int cannonsPerSide = 2;
  double cannonRange = 100.0;
  double cannonPower = 25.0;
  double cannonCooldown = 0.0;

  // Cargo - units that can be deployed
  List<UnitType> cargo = [];
  int maxCargo = 15;

  // Movement state
  bool hasSail = true;
  bool usingPaddles = false;
  double sailEfficiency = 1.2;
  double paddleEfficiency = 0.8;

  // Navigation and movement properties
  Vector2? _lastValidPosition;
  double _stuckTimer = 0.0;
  final double _maxStuckTime = 3.0;
  final double _minDistanceFromLand = 20.0;
  int _currentWaypointIndex = 0;

  // Irregular movement properties (similar to units)
  double _wanderAngle = 0.0;
  double _noiseOffset = 0.0;
  Vector2 _avoidanceForce = Vector2.zero();
  double _pathUpdateTimer = 0.0;
  final double _pathUpdateInterval = 2.0; // Recalculate path every 2 seconds

  // Callbacks for environment detection
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
    _initializeCargo();
    _lastValidPosition = position.clone();
    _noiseOffset = math.Random().nextDouble() * 1000;
    _wanderAngle = math.Random().nextDouble() * 2 * math.pi;
  }

  void _initializeCargo() {
    cargo.clear();
    cargo.add(UnitType.captain);
    for (int i = 0; i < 7; i++) {
      cargo.add(UnitType.archer);
      cargo.add(UnitType.swordsman);
    }
  }

  bool canDeployUnits() {
    return isAtShore && cargo.isNotEmpty && health > 0;
  }

  UnitType? deployUnit(UnitType requestedType) {
    if (!canDeployUnits()) return null;
    for (int i = 0; i < cargo.length; i++) {
      if (cargo[i] == requestedType) {
        return cargo.removeAt(i);
      }
    }
    return null;
  }

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

  Vector2? getDeploymentPosition() {
    if (!isAtShore) return null;

    // Try multiple distances to find land
    for (double distance = radius + 15;
        distance <= radius + 60;
        distance += 5) {
      // Check more angles for better coverage
      for (int angle = 0; angle < 360; angle += 15) {
        double rad = angle * math.pi / 180;
        Vector2 deployPos = position +
            Vector2(
              math.cos(rad) * distance,
              math.sin(rad) * distance,
            );
        if (isOnLandCallback != null && isOnLandCallback!(deployPos)) {
          return deployPos;
        }
      }
    }
    return null;
  }

  /// Check if a position would be valid for the ship
  bool _isValidShipPosition(Vector2 testPosition) {
    if (isOnLandCallback == null) return true;

    // Check multiple points around the ship's radius
    const int checkPoints = 12; // More points for better accuracy
    for (int i = 0; i < checkPoints; i++) {
      double angle = (i / checkPoints) * 2 * math.pi;
      Vector2 checkPos = testPosition +
          Vector2(
            math.cos(angle) * (radius + 5), // Add small buffer
            math.sin(angle) * (radius + 5),
          );

      if (isOnLandCallback!(checkPos)) {
        return false;
      }
    }
    return true;
  }

  /// Set target position and calculate navigation path
  void setTargetPosition(Vector2 target) {
    targetPosition = target.clone();
    isNavigating = true;
    _currentWaypointIndex = 0;
    _pathUpdateTimer = 0.0;

    // Calculate initial path
    _calculateNavigationPath();
  }

  /// Calculate a path around obstacles to reach the target
  void _calculateNavigationPath() {
    if (targetPosition == null || isOnLandCallback == null) {
      navigationPath = null;
      return;
    }

    Vector2 start = position;
    Vector2 end = targetPosition!;

    // Simple pathfinding: if direct path is clear, use it
    if (_isPathClear(start, end)) {
      navigationPath = [end];
      return;
    }

    // Find path around obstacles using waypoints
    List<Vector2> waypoints = _findWaypointsAroundObstacles(start, end);
    navigationPath = waypoints;
  }

  /// Check if a direct path between two points is clear of land
  bool _isPathClear(Vector2 start, Vector2 end) {
    Vector2 direction = end - start;
    double distance = direction.length;
    direction.normalize();

    // Check points along the path
    int steps = (distance / 10).ceil(); // Check every 10 units
    for (int i = 0; i <= steps; i++) {
      double t = i / steps;
      Vector2 checkPoint = start + direction * (distance * t);

      if (!_isValidShipPosition(checkPoint)) {
        return false;
      }
    }
    return true;
  }

  /// Find waypoints to navigate around obstacles
  List<Vector2> _findWaypointsAroundObstacles(Vector2 start, Vector2 end) {
    List<Vector2> waypoints = [];
    Vector2 current = start;
    Vector2 target = end;
    int maxAttempts = 10; // Prevent infinite loops

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (_isPathClear(current, target)) {
        waypoints.add(target);
        break;
      }

      // Find an intermediate waypoint that avoids obstacles
      Vector2? waypoint = _findAvoidanceWaypoint(current, target);
      if (waypoint != null) {
        waypoints.add(waypoint);
        current = waypoint;
      } else {
        // If no waypoint found, try to get closer to target
        Vector2 direction = target - current;
        direction.normalize();
        Vector2 stepPoint = current + direction * 50; // Step 50 units closer

        Vector2 validStep = _findClosestValidPosition(stepPoint);
        waypoints.add(validStep);
        current = validStep;
      }
    }

    return waypoints;
  }

  /// Find a waypoint that avoids obstacles
  Vector2? _findAvoidanceWaypoint(Vector2 start, Vector2 target) {
    Vector2 direction = target - start;
    Vector2 perpendicular = Vector2(-direction.y, direction.x).normalized();

    // Try points perpendicular to the direct path
    List<double> distances = [30.0, 50.0, 80.0]; // Try different distances
    List<double> sides = [-1.0, 1.0]; // Try both sides

    for (double distance in distances) {
      for (double side in sides) {
        Vector2 waypoint =
            start + direction * 0.5 + perpendicular * (distance * side);

        if (_isValidShipPosition(waypoint) && _isPathClear(start, waypoint)) {
          return waypoint;
        }
      }
    }

    return null;
  }

  /// Find the closest valid water position to a target
  Vector2 _findClosestValidPosition(Vector2 target) {
    if (_isValidShipPosition(target)) {
      return target;
    }

    // Search in expanding circles around the target
    for (double radius = 10.0; radius <= 100.0; radius += 10.0) {
      for (int angle = 0; angle < 360; angle += 30) {
        double rad = angle * math.pi / 180;
        Vector2 testPos = target +
            Vector2(
              math.cos(rad) * radius,
              math.sin(rad) * radius,
            );

        if (_isValidShipPosition(testPos)) {
          return testPos;
        }
      }
    }

    return _lastValidPosition ?? position;
  }

  /// Update ship state and position
  void update(double dt) {
    if (health <= 0) return;

    // Update timers
    if (cannonCooldown > 0) cannonCooldown -= dt;
    if (isStuck) {
      _stuckTimer += dt;
      if (_stuckTimer > _maxStuckTime) {
        _forceUnstick();
      }
    }

    _pathUpdateTimer += dt;

    // Update shore status
    _updateShoreStatus();

    // Handle movement
    if (targetPosition != null) {
      _updateNavigationMovement(dt);
    } else {
      // Drift slightly to simulate water movement
      _applyIdleDrift(dt);
    }

    // Ensure we're always in valid water
    if (!_isValidShipPosition(position)) {
      position.setFrom(_lastValidPosition ?? position);
      isStuck = true;
    } else {
      _lastValidPosition = position.clone();
      isStuck = false;
      _stuckTimer = 0.0;
    }
  }

  /// Update movement following navigation path
  void _updateNavigationMovement(double dt) {
    if (navigationPath == null || navigationPath!.isEmpty) {
      _calculateNavigationPath();
      return;
    }

    // Recalculate path periodically or if stuck
    if (_pathUpdateTimer > _pathUpdateInterval || isStuck) {
      _calculateNavigationPath();
      _pathUpdateTimer = 0.0;
    }

    // Get current waypoint
    Vector2 currentWaypoint = navigationPath![_currentWaypointIndex];
    Vector2 directionToWaypoint = currentWaypoint - position;
    double distanceToWaypoint = directionToWaypoint.length;

    // Check if we've reached the current waypoint
    if (distanceToWaypoint < radius * 1.5) {
      _currentWaypointIndex++;

      // Check if we've reached the final destination
      if (_currentWaypointIndex >= navigationPath!.length) {
        // Reached destination
        targetPosition = null;
        navigationPath = null;
        isNavigating = false;
        velocity = Vector2.zero();
        return;
      }

      // Move to next waypoint
      currentWaypoint = navigationPath![_currentWaypointIndex];
      directionToWaypoint = currentWaypoint - position;
      distanceToWaypoint = directionToWaypoint.length;
    }

    // Apply irregular movement similar to units
    directionToWaypoint.normalize();

    // Add wandering behavior for natural ship movement
    _wanderAngle += (math.Random().nextDouble() - 0.5) * 0.2;
    Vector2 wanderForce = Vector2(
      math.cos(_wanderAngle) * 0.3,
      math.sin(_wanderAngle) * 0.3,
    );

    // Add some noise for irregular movement
    _noiseOffset += dt;
    Vector2 noiseForce = Vector2(
      math.sin(_noiseOffset * 2.0) * 0.2,
      math.cos(_noiseOffset * 1.7) * 0.2,
    );

    // Calculate avoidance force from nearby land
    _avoidanceForce = _calculateLandAvoidanceForce();

    // Combine forces
    Vector2 targetForce = directionToWaypoint * 1.0;
    Vector2 totalForce =
        targetForce + wanderForce + noiseForce + _avoidanceForce;

    // Calculate effective speed
    double effectiveSpeed = maxSpeed;
    if (hasSail && !usingPaddles) {
      effectiveSpeed *= sailEfficiency;
    } else if (usingPaddles) {
      effectiveSpeed *= paddleEfficiency;
    }

    // Set velocity with irregular movement
    velocity = totalForce.normalized() * effectiveSpeed;

    // Damping for more realistic ship movement
    velocity *= 0.9;

    // Calculate new position
    Vector2 newPosition = position + velocity * dt;

    // Validate new position
    if (_isValidShipPosition(newPosition)) {
      position = newPosition;
      _lastValidPosition = position.clone();
      isStuck = false;
      _stuckTimer = 0.0;
    } else {
      // Position would be invalid, try to find alternative
      Vector2 alternativePos = _findAlternativePosition(newPosition);
      if (_isValidShipPosition(alternativePos)) {
        position = alternativePos;
        _lastValidPosition = position.clone();
      } else {
        // Can't move, mark as stuck
        isStuck = true;
        velocity = Vector2.zero();
      }
    }
  }

  /// Calculate avoidance force from nearby land
  Vector2 _calculateLandAvoidanceForce() {
    if (isOnLandCallback == null) return Vector2.zero();

    Vector2 avoidanceForce = Vector2.zero();
    const double detectionRadius = 40.0;
    const int rayCount = 8;

    for (int i = 0; i < rayCount; i++) {
      double angle = (i / rayCount) * 2 * math.pi;
      Vector2 rayDirection = Vector2(math.cos(angle), math.sin(angle));

      // Cast ray to detect land
      for (double distance = radius + 5;
          distance <= detectionRadius;
          distance += 5) {
        Vector2 checkPoint = position + rayDirection * distance;

        if (isOnLandCallback!(checkPoint)) {
          // Found land, add avoidance force
          Vector2 avoidDirection = -rayDirection;
          double strength = (detectionRadius - distance) / detectionRadius;
          avoidanceForce += avoidDirection * strength * 0.5;
          break;
        }
      }
    }

    return avoidanceForce;
  }

  /// Find alternative position when direct movement is blocked
  Vector2 _findAlternativePosition(Vector2 blockedPosition) {
    Vector2 direction = blockedPosition - position;
    Vector2 perpendicular = Vector2(-direction.y, direction.x).normalized();

    // Try moving perpendicular to the blocked direction
    List<Vector2> alternatives = [
      position + perpendicular * 10,
      position - perpendicular * 10,
      position + direction.normalized() * 5, // Try smaller step forward
    ];

    for (Vector2 alternative in alternatives) {
      if (_isValidShipPosition(alternative)) {
        return alternative;
      }
    }

    return position; // Stay in place if no alternative found
  }

  /// Apply idle drift when ship has no target
  void _applyIdleDrift(double dt) {
    // Small random drift to simulate water currents
    _noiseOffset += dt * 0.5;
    Vector2 driftForce = Vector2(
      math.sin(_noiseOffset) * 0.1,
      math.cos(_noiseOffset * 0.8) * 0.1,
    );

    velocity = driftForce;
    Vector2 newPosition = position + velocity * dt;

    if (_isValidShipPosition(newPosition)) {
      position = newPosition;
    }
  }

  /// Force ship to unstick from land
  void _forceUnstick() {
    if (_lastValidPosition != null) {
      position.setFrom(_lastValidPosition!);
      velocity = Vector2.zero();
      isStuck = false;
      _stuckTimer = 0.0;

      // Clear current navigation to prevent getting stuck again
      navigationPath = null;
      targetPosition = null;
      isNavigating = false;
    }
  }

  /// Check if ship is at shore (can deploy units)
  void _updateShoreStatus() {
    if (isNearShoreCallback != null) {
      isAtShore = isNearShoreCallback!(position);
    } else if (isOnLandCallback != null) {
      // Enhanced fallback shore detection
      isAtShore = false;

      // Check multiple ranges and patterns
      List<double> checkDistances = [15.0, 20.0, 25.0, 30.0, 35.0];

      for (double shoreBuffer in checkDistances) {
        // Check in a circle around the ship
        for (int angle = 0; angle < 360; angle += 30) {
          double rad = angle * math.pi / 180;
          Vector2 checkPos = position +
              Vector2(
                math.cos(rad) * shoreBuffer,
                math.sin(rad) * shoreBuffer,
              );

          if (isOnLandCallback!(checkPos)) {
            isAtShore = true;
            return; // Exit as soon as we find shore
          }
        }
      }

      // Additional check: look for land in a grid pattern around the ship
      for (double x = -30; x <= 30; x += 10) {
        for (double y = -30; y <= 30; y += 10) {
          Vector2 checkPos = position + Vector2(x, y);
          if (isOnLandCallback!(checkPos)) {
            isAtShore = true;
            return;
          }
        }
      }
    }
  }

  /// Fire cannons at target
  bool fireCannsAt(Vector2 target) {
    if (cannonCooldown > 0 || health <= 0) return false;
    double distance = position.distanceTo(target);
    if (distance > cannonRange) return false;
    cannonCooldown = 3.0;
    return true;
  }

  /// Take damage
  void takeDamage(double damage) {
    health -= damage;
    health = math.max(0, health);
  }

  /// Repair ship
  void repair(double amount) {
    if (isAtShore) {
      health += amount;
      health = math.min(maxHealth, health);
    }
  }

  /// Stop movement
  void stop() {
    targetPosition = null;
    navigationPath = null;
    isNavigating = false;
    velocity = Vector2.zero();
  }

  /// Get ship status for UI
  String getStatusText() {
    if (health <= 0) return "DESTROYED";
    if (isStuck) return "STUCK";
    if (isAtShore) return "AT SHORE - CAN DEPLOY";
    if (isNavigating) return "NAVIGATING";
    if (targetPosition != null) return "MOVING";
    return "AT SEA";
  }

  /// Get health percentage
  double get healthPercent => health / maxHealth;

  /// Get cargo count
  int get cargoCount => cargo.length;

  /// Check if ship is destroyed
  bool get isDestroyed => health <= 0;

  /// Get current waypoint index for UI
  int getCurrentWaypointIndex() => _currentWaypointIndex;
}
