import 'dart:ui'; // Add this import for Offset type
import '../models/unit_model.dart';

/// Simple rule-based system for game logic with proper validation
class GameRulesEngine {
  /// Apply all game rules to a list of units
  static GameState processRules(List<UnitModel> units, {Offset? apex}) {
    final gameState = GameState();

    // Rule 1: Remove dead units
    final aliveUnits = units.where((unit) => unit.health > 0).toList();
    gameState.unitsToRemove =
        units.where((unit) => unit.health <= 0).map((u) => u.id).toList();

    // Rule 2: Check victory conditions with proper validation
    gameState.victoryState = _checkVictoryConditions(aliveUnits, units);

    // Rule 3: Apply unit abilities based on context
    for (final unit in aliveUnits) {
      _applyUnitAbilities(unit, aliveUnits, apex);
    }

    // Rule 4: Count units by team
    gameState.blueUnits = aliveUnits.where((u) => u.team == Team.blue).length;
    gameState.redUnits = aliveUnits.where((u) => u.team == Team.red).length;

    // Rule 5: Calculate team health percentages
    gameState.blueHealthPercent = _calculateTeamHealth(aliveUnits, Team.blue);
    gameState.redHealthPercent = _calculateTeamHealth(aliveUnits, Team.red);

    return gameState;
  }

  /// Rule: Check various victory conditions with better validation
  static VictoryState _checkVictoryConditions(
      List<UnitModel> aliveUnits, List<UnitModel> allUnits) {
    // Don't check victory until both teams have units and game has progressed
    final blueTotal = allUnits.where((u) => u.team == Team.blue).length;
    final redTotal = allUnits.where((u) => u.team == Team.red).length;

    // Require minimum units and time before victory can be achieved
    if (blueTotal == 0 || redTotal == 0 || allUnits.length < 2) {
      return VictoryState(hasWinner: false);
    }

    // Flag victory - highest priority
    for (final unit in aliveUnits) {
      if (unit.type == UnitType.captain && unit.hasPlantedFlag) {
        return VictoryState(
          hasWinner: true,
          winner: unit.team,
          reason: VictoryReason.flagCapture,
        );
      }
    }

    final blueUnits = aliveUnits.where((u) => u.team == Team.blue).toList();
    final redUnits = aliveUnits.where((u) => u.team == Team.red).toList();

    // Total elimination victory - only if both teams had units
    if (blueUnits.isEmpty && redUnits.isNotEmpty && blueTotal > 0) {
      return VictoryState(
        hasWinner: true,
        winner: Team.red,
        reason: VictoryReason.elimination,
      );
    }

    if (redUnits.isEmpty && blueUnits.isNotEmpty && redTotal > 0) {
      return VictoryState(
        hasWinner: true,
        winner: Team.blue,
        reason: VictoryReason.elimination,
      );
    }

    // Captain elimination - special case (only if captains were spawned)
    final blueCaptains =
        blueUnits.where((u) => u.type == UnitType.captain).toList();
    final redCaptains =
        redUnits.where((u) => u.type == UnitType.captain).toList();
    final blueCaptainsTotal = allUnits
        .where((u) => u.team == Team.blue && u.type == UnitType.captain)
        .length;
    final redCaptainsTotal = allUnits
        .where((u) => u.team == Team.red && u.type == UnitType.captain)
        .length;

    // Only check captain elimination if both teams had captains
    if (blueCaptainsTotal > 0 && redCaptainsTotal > 0) {
      if (blueCaptains.isEmpty && redCaptains.isNotEmpty) {
        return VictoryState(
          hasWinner: true,
          winner: Team.red,
          reason: VictoryReason.captainElimination,
        );
      }

      if (redCaptains.isEmpty && blueCaptains.isNotEmpty) {
        return VictoryState(
          hasWinner: true,
          winner: Team.blue,
          reason: VictoryReason.captainElimination,
        );
      }
    }

    return VictoryState(hasWinner: false);
  }

  /// Rule: Apply context-specific abilities to units
  static void _applyUnitAbilities(
      UnitModel unit, List<UnitModel> allUnits, Offset? apex) {
    switch (unit.type) {
      case UnitType.captain:
        // Captains inspire nearby friendly units
        final nearbyFriendlies = allUnits
            .where((other) =>
                other.team == unit.team &&
                other.id != unit.id &&
                unit.position.distanceTo(other.position) < 50.0)
            .toList();

        // Boost health regeneration for nearby units
        for (final friendly in nearbyFriendlies) {
          if (friendly.health < friendly.maxHealth) {
            friendly.health = (friendly.health + 5.0 * 0.016)
                .clamp(0.0, friendly.maxHealth); // 5 HP/sec
          }
        }
        break;

      case UnitType.swordsman:
        // Swordsmen get defense bonus when stationary
        if (unit.velocity.length < 2.0) {
          unit.defense = 15.0; // Increased from base 10.0
        } else {
          unit.defense = 10.0; // Base defense
        }
        break;

      case UnitType.archer:
        // Archers get longer range when not engaged in melee
        final nearbyEnemies = allUnits
            .where((other) =>
                other.team != unit.team &&
                unit.position.distanceTo(other.position) < 30.0)
            .toList();

        if (nearbyEnemies.isEmpty) {
          unit.attackRange = 120.0; // Extended range when safe
        } else {
          unit.attackRange = 80.0; // Reduced range in close combat
        }
        break;
    }
  }

  /// Rule: Calculate team health percentage
  static double _calculateTeamHealth(List<UnitModel> units, Team team) {
    final teamUnits = units.where((u) => u.team == team).toList();
    if (teamUnits.isEmpty) return 0.0;

    double totalHealth = teamUnits.fold(0.0, (sum, unit) => sum + unit.health);
    double maxHealth = teamUnits.fold(0.0, (sum, unit) => sum + unit.maxHealth);

    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }
}

/// Game state result from rules processing
class GameState {
  bool hasVictory = false;
  VictoryState victoryState = VictoryState(hasWinner: false);
  List<String> unitsToRemove = [];
  int blueUnits = 0;
  int redUnits = 0;
  double blueHealthPercent = 1.0;
  double redHealthPercent = 1.0;
}

/// Victory state information
class VictoryState {
  final bool hasWinner;
  final Team? winner;
  final VictoryReason? reason;

  VictoryState({
    required this.hasWinner,
    this.winner,
    this.reason,
  });
}

/// Types of victory conditions
enum VictoryReason {
  flagCapture,
  elimination,
  captainElimination,
}
