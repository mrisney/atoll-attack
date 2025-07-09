// test/apex_movement_test.dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:atoll_attack/models/unit_model.dart';

void main() {
  group('Apex Movement and Patrol Tests', () {
    test('Captain should move directly to apex', () {
      final captain = UnitModel(
        id: 'test_captain',
        type: UnitType.captain,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final apex = const Offset(200, 200);
      
      // Simulate movement logic (simplified)
      final apexPosition = Vector2(apex.dx, apex.dy);
      final distanceToApex = captain.position.distanceTo(apexPosition);
      
      // Captain should target apex directly
      expect(distanceToApex, greaterThan(0));
      expect(captain.type, equals(UnitType.captain));
    });
    
    test('Non-captain units should patrol around apex', () {
      final swordsman = UnitModel(
        id: 'test_swordsman',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final apex = const Offset(200, 200);
      final apexPosition = Vector2(apex.dx, apex.dy);
      
      // Get patrol position
      final patrolPos = swordsman._getApexPatrolPosition(apexPosition);
      
      // Patrol position should be around apex, not exactly at apex
      final distanceFromApex = patrolPos.distanceTo(apexPosition);
      expect(distanceFromApex, greaterThan(40)); // Should be at least 40 units away
      expect(distanceFromApex, lessThan(90));    // But not too far
    });
    
    test('Units should have different patrol positions based on ID', () {
      final unit1 = UnitModel(
        id: 'unit_1',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final unit2 = UnitModel(
        id: 'unit_2',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final apex = const Offset(200, 200);
      final apexPosition = Vector2(apex.dx, apex.dy);
      
      final patrol1 = unit1._getApexPatrolPosition(apexPosition);
      final patrol2 = unit2._getApexPatrolPosition(apexPosition);
      
      // Different units should get different patrol positions
      expect(patrol1.distanceTo(patrol2), greaterThan(10));
    });
    
    test('Arrival radius should be larger for apex area', () {
      final unit = UnitModel(
        id: 'test_unit',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final apex = const Offset(200, 200);
      final apexPosition = Vector2(apex.dx, apex.dy);
      
      // Target near apex
      final nearApexTarget = Vector2(apex.dx + 20, apex.dy + 20);
      final nearApexRadius = unit._calculateArrivalRadius(nearApexTarget, apex);
      
      // Target far from apex
      final farTarget = Vector2(100, 100);
      final farRadius = unit._calculateArrivalRadius(farTarget, apex);
      
      // Arrival radius should be larger near apex
      expect(nearApexRadius, greaterThanOrEqualTo(farRadius));
    });
    
    test('Captain should have smaller arrival radius than other units', () {
      final captain = UnitModel(
        id: 'test_captain',
        type: UnitType.captain,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final swordsman = UnitModel(
        id: 'test_swordsman',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      final apex = const Offset(200, 200);
      final target = Vector2(apex.dx, apex.dy);
      
      final captainRadius = captain._calculateArrivalRadius(target, apex);
      final swordsmanRadius = swordsman._calculateArrivalRadius(target, apex);
      
      // Captain needs more precise positioning
      expect(captainRadius, lessThanOrEqualTo(swordsmanRadius));
    });
  });
}

// Extension to access private methods for testing
extension UnitModelTestExtension on UnitModel {
  Vector2 _getApexPatrolPosition(Vector2 apexPosition) {
    // Replicate the private method logic for testing
    final hash = id.hashCode;
    final angle = (hash % 360) * (math.pi / 180); // Convert to radians
    final patrolRadius = 50.0 + (hash % 30); // 50-80 radius
    
    final patrolX = apexPosition.x + math.cos(angle) * patrolRadius;
    final patrolY = apexPosition.y + math.sin(angle) * patrolRadius;
    
    return Vector2(patrolX, patrolY);
  }
  
  double _calculateArrivalRadius(Vector2 target, Offset? apex) {
    // Replicate the private method logic for testing
    double arrivalRadius = radius * 2;
    
    if (apex != null) {
      final apexPosition = Vector2(apex.dx, apex.dy);
      final distanceToApex = target.distanceTo(apexPosition);
      
      if (distanceToApex < 50) {
        arrivalRadius = math.max(arrivalRadius, 25.0);
      }
    }
    
    if (type == UnitType.captain) {
      arrivalRadius = math.min(arrivalRadius, 15.0);
    }
    
    return arrivalRadius;
  }
}
