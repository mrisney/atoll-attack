import '../models/unit_model.dart';
import 'package:flame/components.dart';

/// Handles special abilities for different unit types
class UnitAbilities {
  /// Calculate archer's attack range bonus based on elevation
  static double getArcherRangeBonus(double elevation) {
    // Higher elevation gives better range
    if (elevation > 0.7) return 50.0; // Peak
    if (elevation > 0.5) return 30.0; // High ground
    if (elevation > 0.4) return 15.0; // Mid elevation
    return 0.0; // Low ground
  }
  
  /// Check if captain can plant flag at current position
  static bool canPlantFlag(UnitModel captain, Vector2 apexPosition) {
    if (captain.type != UnitType.captain) return false;
    
    double distance = captain.position.distanceTo(apexPosition);
    return distance < captain.radius * 2;
  }
  
  /// Get swordsman's shield defense bonus
  static double getSwordsmanDefenseBonus(UnitModel swordsman) {
    if (swordsman.type != UnitType.swordsman) return 0.0;
    
    // Swordsmen get defense bonus when not moving (bracing with shield)
    if (swordsman.velocity.length < 0.5) {
      return 5.0; // Additional defense when stationary
    }
    return 0.0;
  }
  
  /// Apply special ability effects based on unit type
  static void applyAbilities(UnitModel unit, double? elevation, Vector2? apexPosition) {
    switch (unit.type) {
      case UnitType.archer:
        if (elevation != null) {
          unit.attackRange = 100.0 + getArcherRangeBonus(elevation);
        }
        break;
        
      case UnitType.swordsman:
        unit.defense = 10.0 + getSwordsmanDefenseBonus(unit);
        break;
        
      case UnitType.captain:
        if (apexPosition != null) {
          if (canPlantFlag(unit, apexPosition)) {
            unit.hasPlantedFlag = true;
          }
        }
        break;
    }
  }
}