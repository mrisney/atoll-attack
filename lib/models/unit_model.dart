import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import 'package:a_star/a_star.dart';
import '../rules/combat_rules.dart';
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
  }) : 
    // Set type-specific properties
    attackRange = type == UnitType.archer ? 50.0 : (type == UnitType.swordsman ? 15.0 : 0.0),
    attackPower = type == UnitType.archer ? 8.0 : (type == UnitType.swordsman ? 12.0 : 0.0),
    defense = type == UnitType.swordsman ? 10.0 : 3.0,
    health = type == UnitType.swordsman ? 100.0 : (type == UnitType.captain ? 60.0 : 80.0),
    maxHealth = type == UnitType.swordsman ? 100.0 : (type == UnitType.captain ? 60.0 : 80.0),
    // Set movement properties with type-specific defaults from config
    maxSpeed = maxSpeed ?? (type == UnitType.captain ? kCaptainSpeed : (type == UnitType.archer ? kArcherSpeed : kSwordsmanSpeed)),
    maxForce = maxForce ?? 100.0,
    mass = mass ?? (type == UnitType.swordsman ? 1.5 : 1.0),
    radius = radius ?? (type == UnitType.swordsman ? 8.0 : (type == UnitType.captain ? 6.0 : 7.0)),
    color = color ?? (team == Team.blue ? 
      (type == UnitType.captain ? Colors.blue.shade700 : (type == UnitType.swordsman ? Colors.blue.shade500 : Colors.blue.shade300)) :
      (type == UnitType.captain ? Colors.red.shade700 : (type == UnitType.swordsman ? Colors.red.shade500 : Colors.red.shade300))),
    velocity = velocity ?? Vector2.zero(),
    targetPosition = targetPosition ?? position.clone() {
      _noiseOffset = math.Random().nextDouble() * 1000;
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
    // Make it harder for captain to plant flag - must be closer to apex
    if (distance < radius * 1.5) {
      // Captain needs to stay at apex for a moment before planting flag
      if (velocity.length < 1.0) {
        hasPlantedFlag = true;
        return true;
      }
    }
    return false;
  }
  
  void update(double dt, List<UnitModel> units, Offset? apex, {double? elevationAtPosition}) {
    // Skip update if dead
    if (health <= 0) return;
    
    // Adjust archer range based on elevation
    double effectiveAttackRange = attackRange;
    if (type == UnitType.archer) {
      // If archer is at high elevation (> 0.6), increase range to 100m
      if (elevationAtPosition != null && elevationAtPosition > 0.6) {
        effectiveAttackRange = 100.0;
      }
    }
    
    // Combat logic - check for enemies in range, but only if not being redirected by player
    if (!forceRedirect) {
      final enemies = units.where((u) => u.team != team && u.health > 0).toList();
      for (final enemy in enemies) {
        double distance = position.distanceTo(enemy.position);
        if (distance <= effectiveAttackRange && attackPower > 0) {
          // Attack enemy
          state = UnitState.attacking;
          enemy.health -= attackPower * dt * 0.5;
          
          // Enemy counterattacks if in range
          if (enemy.attackRange >= distance && enemy.attackPower > 0) {
            health -= enemy.attackPower * dt * 0.5;
          }
          
          // Slow down when attacking
          velocity *= 0.8;
          break;
        }
      }
    } else {
      // If being redirected, prioritize movement
      state = isSelected ? UnitState.selected : UnitState.moving;
      
      // Reset the force redirect flag after a short time to allow normal behavior to resume
      forceRedirect = false;
    }
    
    // Find allies for flocking
    final allies = units.where((u) => u.team == team && u.id != id && u.health > 0).toList();
    
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
    // Otherwise move toward apex if not at flag
    else if (apex != null && !hasPlantedFlag) {
      moveTarget = Vector2(apex.dx, apex.dy);
    }
    
    // Apply movement forces
    if (moveTarget != null) {
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
    
    // Apply separation from other units
    Vector2 separation = _calculateSeparation(units);
    applyForce(separation);
    
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
    
    // Check if captain reached apex
    if (type == UnitType.captain) {
      checkApexReached(apex);
    }
    
    // Update state
    if (hasPlantedFlag) {
      state = UnitState.idle;
      // Even when flag is planted, captain should sway a bit
      if (type == UnitType.captain) {
        final now = DateTime.now().millisecondsSinceEpoch / 500;
        Vector2 smallMovement = Vector2(
          math.sin(now) * 0.5,
          math.cos(now) * 0.5,
        );
        position += smallMovement * dt;
      } else {
        velocity = Vector2.zero();
      }
    } else if (state == UnitState.attacking) {
      // Keep attacking state for a short time but don't stop moving
    } else {
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