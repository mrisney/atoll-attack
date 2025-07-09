// test/ship_boarding_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:atoll_attack/models/unit_model.dart';
import 'package:atoll_attack/models/ship_model.dart';

void main() {
  group('Ship Boarding and Healing Tests', () {
    test('Unit should seek ship when health is low', () {
      final unit = UnitModel(
        id: 'test_unit',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      // Set health to low
      unit.health = 30.0; // 25% health (below 50% threshold)
      
      // Should seek ship
      expect(unit.shouldSeekShip(), isTrue);
      
      // Set health to high
      unit.health = 80.0; // 67% health (above 50% threshold)
      
      // Should not seek ship
      expect(unit.shouldSeekShip(), isFalse);
    });
    
    test('Unit should not seek ship when in combat', () {
      final unit = UnitModel(
        id: 'test_unit',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      // Set health to low and in combat
      unit.health = 30.0;
      unit.isInCombat = true;
      
      // Should not seek ship when in combat
      expect(unit.shouldSeekShip(), isFalse);
    });
    
    test('Unit should heal while on ship', () {
      final unit = UnitModel(
        id: 'test_unit',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
      );
      
      // Set low health and board ship
      unit.health = 50.0;
      unit.isBoarded = true;
      
      final initialHealth = unit.health;
      
      // Process healing for 1 second
      unit.processHealing(1.0);
      
      // Health should increase
      expect(unit.health, greaterThan(initialHealth));
      expect(unit.health, lessThanOrEqualTo(unit.maxHealth));
    });
    
    test('Unit should disembark when fully healed', () {
      final ship = ShipModel(
        id: 'test_ship',
        team: Team.blue,
        position: Vector2(200, 200),
      );
      
      final unit = UnitModel(
        id: 'test_unit',
        type: UnitType.swordsman,
        position: Vector2(100, 100),
        playerId: 'blue',
        getAllShipsCallback: () => [MockShipComponent(ship)],
      );
      
      // Set almost full health and board ship
      unit.health = unit.maxHealth - 5.0;
      unit.isBoarded = true;
      unit.targetShipId = ship.id;
      
      // Process healing to reach full health
      unit.processHealing(1.0);
      
      // Should be fully healed and disembarked
      expect(unit.health, equals(unit.maxHealth));
      expect(unit.isBoarded, isFalse);
      expect(unit.targetShipId, isNull);
    });
  });
}

/// Mock ship component for testing
class MockShipComponent {
  final ShipModel model;
  
  MockShipComponent(this.model);
  
  Vector2? getBoardingPosition() {
    return Vector2(model.position.x + 30, model.position.y);
  }
  
  void disembarkUnit(String unitId) {
    // Mock implementation
  }
}
