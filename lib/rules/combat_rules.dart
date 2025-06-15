import '../models/unit_model.dart';

/// Handles combat calculations between units
class CombatRules {
  /// Calculate damage based on attacker and defender stats
  static double calculateDamage(UnitModel attacker, UnitModel defender) {
    // Base damage from attacker's power
    double damage = attacker.attackPower;
    
    // Apply defense reduction
    damage *= (1.0 - (defender.defense / 100.0));
    
    // Ensure minimum damage
    damage = damage.clamp(1.0, attacker.attackPower);
    
    return damage;
  }
  
  /// Check if attack is possible based on range and other factors
  static bool canAttack(UnitModel attacker, UnitModel defender) {
    // Skip if same team
    if (attacker.team == defender.team) return false;
    
    // Skip if attacker has no attack power
    if (attacker.attackPower <= 0) return false;
    
    // Check range
    double distance = attacker.position.distanceTo(defender.position);
    return distance <= attacker.attackRange;
  }
  
  /// Find the best target for a unit to attack
  static UnitModel? findBestTarget(UnitModel attacker, List<UnitModel> potentialTargets) {
    UnitModel? bestTarget;
    double closestDistance = double.infinity;
    
    for (final target in potentialTargets) {
      // Skip invalid targets
      if (!canAttack(attacker, target)) continue;
      
      double distance = attacker.position.distanceTo(target.position);
      if (distance < closestDistance) {
        bestTarget = target;
        closestDistance = distance;
      }
    }
    
    return bestTarget;
  }
}