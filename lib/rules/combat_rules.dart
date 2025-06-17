import '../models/unit_model.dart';

/// Handles combat calculations between units with enhanced mechanics
class CombatRules {
  /// Calculate damage based on attacker and defender stats with type advantages
  static double calculateDamage(UnitModel attacker, UnitModel defender) {
    // Base damage from attacker's power
    double damage = attacker.attackPower;

    // Type advantages/disadvantages
    damage *= _getTypeAdvantageMultiplier(attacker.type, defender.type);

    // Apply defense reduction (defense reduces damage by up to 50%)
    double defenseReduction = (defender.defense / 100.0).clamp(0.0, 0.5);
    damage *= (1.0 - defenseReduction);

    // Ensure minimum damage (at least 20% of base damage)
    damage =
        damage.clamp(attacker.attackPower * 0.2, attacker.attackPower * 2.0);

    return damage;
  }

  /// Get type advantage multiplier
  static double _getTypeAdvantageMultiplier(
      UnitType attackerType, UnitType defenderType) {
    // Rock-paper-scissors style advantages
    switch (attackerType) {
      case UnitType.swordsman:
        // Swordsmen are effective against archers (can close distance)
        if (defenderType == UnitType.archer) return 1.3;
        // Swordsmen struggle against captains (leadership/experience)
        if (defenderType == UnitType.captain) return 0.9;
        break;

      case UnitType.archer:
        // Archers are effective against captains (can pick them off at range)
        if (defenderType == UnitType.captain) return 1.2;
        // Archers are vulnerable to swordsmen in close combat
        if (defenderType == UnitType.swordsman) return 0.8;
        break;

      case UnitType.captain:
        // Captains are effective against swordsmen (tactical superiority)
        if (defenderType == UnitType.swordsman) return 1.1;
        // Captains are vulnerable to archer fire
        if (defenderType == UnitType.archer) return 0.9;
        break;
    }

    // Same type units fight evenly
    return 1.0;
  }

  /// Check if attack is possible based on range and other factors
  static bool canAttack(UnitModel attacker, UnitModel defender) {
    // Skip if same team
    if (attacker.team == defender.team) return false;

    // Skip if attacker has no attack power
    if (attacker.attackPower <= 0) return false;

    // Skip if either unit is dead
    if (attacker.health <= 0 || defender.health <= 0) return false;

    // Calculate effective range
    double effectiveRange = attacker.attackRange;

    // Archers get extended range (simulating high ground advantage)
    if (attacker.type == UnitType.archer) {
      effectiveRange = 80.0; // Extended range for archers
    }

    // Check range
    double distance = attacker.position.distanceTo(defender.position);
    return distance <= effectiveRange;
  }

  /// Find the best target for a unit to attack based on priority system
  static UnitModel? findBestTarget(
      UnitModel attacker, List<UnitModel> potentialTargets) {
    if (potentialTargets.isEmpty) return null;

    UnitModel? bestTarget;
    double bestScore = -1;

    for (final target in potentialTargets) {
      // Skip invalid targets
      if (!canAttack(attacker, target)) continue;

      double score = _calculateTargetPriority(attacker, target);
      if (score > bestScore) {
        bestTarget = target;
        bestScore = score;
      }
    }

    return bestTarget;
  }

  /// Calculate target priority score (higher = better target)
  static double _calculateTargetPriority(UnitModel attacker, UnitModel target) {
    double score = 0;

    // Distance factor (closer targets are better)
    double distance = attacker.position.distanceTo(target.position);
    double maxRange = attacker.attackRange;
    score +=
        (maxRange - distance) / maxRange * 50; // Up to 50 points for proximity

    // Health factor (weaker targets are easier to finish)
    double healthPercent = target.health / target.maxHealth;
    score += (1.0 - healthPercent) * 30; // Up to 30 points for low health

    // Type advantage factor
    double typeAdvantage =
        _getTypeAdvantageMultiplier(attacker.type, target.type);
    score += (typeAdvantage - 1.0) * 40; // +/-40 points based on type advantage

    // Unit type priority (captains are high value targets)
    switch (target.type) {
      case UnitType.captain:
        score += 25; // High priority
        break;
      case UnitType.archer:
        score += 15; // Medium priority
        break;
      case UnitType.swordsman:
        score += 10; // Lower priority
        break;
    }

    // If target is already engaged with another unit, lower priority
    if (target.isInCombat) {
      score -= 20;
    }

    return score;
  }

  /// Check if two units should engage in mutual combat
  static bool shouldEngageMutualCombat(UnitModel unit1, UnitModel unit2) {
    // Must be different teams
    if (unit1.team == unit2.team) return false;

    // Both must be alive
    if (unit1.health <= 0 || unit2.health <= 0) return false;

    // At least one must be able to attack the other
    return canAttack(unit1, unit2) || canAttack(unit2, unit1);
  }

  /// Get combat effectiveness rating for a unit (0.0 to 1.0)
  static double getCombatEffectiveness(UnitModel unit) {
    if (unit.health <= 0) return 0.0;

    // Base effectiveness from health percentage
    double effectiveness = unit.health / unit.maxHealth;

    // Modify based on unit state
    switch (unit.state) {
      case UnitState.attacking:
        effectiveness *= 1.1; // Slight bonus when actively attacking
        break;
      case UnitState.raisingFlag:
        effectiveness *= 0.3; // Very vulnerable while raising flag
        break;
      case UnitState.moving:
        effectiveness *= 0.9; // Slight penalty while moving
        break;
      default:
        break;
    }

    // Account for attack cooldown
    if (unit.attackCooldown > 0) {
      effectiveness *= 0.8; // Reduced effectiveness during cooldown
    }

    return effectiveness.clamp(0.0, 1.0);
  }

  /// Estimate combat outcome between two units (returns probability unit1 wins)
  static double estimateCombatOutcome(UnitModel unit1, UnitModel unit2) {
    if (unit1.team == unit2.team) return 0.5; // Same team, no combat

    double unit1Power =
        unit1.attackPower * _getTypeAdvantageMultiplier(unit1.type, unit2.type);
    double unit2Power =
        unit2.attackPower * _getTypeAdvantageMultiplier(unit2.type, unit1.type);

    double unit1Survivability = unit1.health + unit1.defense;
    double unit2Survivability = unit2.health + unit2.defense;

    double unit1Score = unit1Power + unit1Survivability * 0.5;
    double unit2Score = unit2Power + unit2Survivability * 0.5;

    double totalScore = unit1Score + unit2Score;
    return totalScore > 0 ? unit1Score / totalScore : 0.5;
  }
}
