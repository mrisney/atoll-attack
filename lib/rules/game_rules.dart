import 'dart:ui';
import '../models/unit_model.dart';
import '../config.dart';

/// Centralized game rules file that handles all game logic
class GameRules {
  // Track units remaining for each team
  static int _blueUnitsRemaining = kTotalUnitsPerTeam;
  static int _redUnitsRemaining = kTotalUnitsPerTeam;
  
  // Reset game state
  static void resetGame() {
    _blueUnitsRemaining = kTotalUnitsPerTeam;
    _redUnitsRemaining = kTotalUnitsPerTeam;
  }
  
  // Get units remaining for a team
  static int getUnitsRemaining(Team team) {
    return team == Team.blue ? _blueUnitsRemaining : _redUnitsRemaining;
  }
  
  // Decrement units remaining when a unit is killed
  static void decrementUnitsRemaining(Team team) {
    if (team == Team.blue) {
      if (_blueUnitsRemaining > 0) _blueUnitsRemaining--;
    } else {
      if (_redUnitsRemaining > 0) _redUnitsRemaining--;
    }
  }
  
  // Check if a team can spawn more units
  static bool canSpawnMoreUnits(Team team) {
    return getUnitsRemaining(team) > 0;
  }
  
  // Check if a team can spawn a specific unit type
  static bool canSpawnUnitType(Team team, UnitType type, List<UnitModel> units) {
    // Always check total units first
    if (!canSpawnMoreUnits(team)) return false;
    
    // Captain is limited to 1 per team
    if (type == UnitType.captain) {
      return !hasCaptain(team, units);
    }
    
    // Other unit types are only limited by total units
    return true;
  }
  
  // Check if a team already has a captain
  static bool hasCaptain(Team team, List<UnitModel> units) {
    return units.any((u) => u.team == team && u.type == UnitType.captain && u.health > 0);
  }
  
  /// Process all game rules and return the current game state
  static GameState processRules(List<UnitModel> units, {Offset? apex}) {
    final gameState = GameState();

    // Rule 1: Remove dead units
    final aliveUnits = units.where((unit) => unit.health > 0).toList();
    gameState.unitsToRemove = units.where((unit) => unit.health <= 0).map((u) => u.id).toList();

    // Rule 2: Check victory conditions
    gameState.victoryState = checkVictoryConditions(aliveUnits, units);

    // Rule 3: Count units by team
    gameState.blueUnits = aliveUnits.where((u) => u.team == Team.blue).length;
    gameState.redUnits = aliveUnits.where((u) => u.team == Team.red).length;

    // Rule 4: Calculate team health percentages
    gameState.blueHealthPercent = calculateTeamHealth(aliveUnits, Team.blue);
    gameState.redHealthPercent = calculateTeamHealth(aliveUnits, Team.red);
    
    // Rule 5: Set remaining units
    gameState.blueUnitsRemaining = _blueUnitsRemaining;
    gameState.redUnitsRemaining = _redUnitsRemaining;

    return gameState;
  }

  /// Check victory conditions
  static VictoryState checkVictoryConditions(List<UnitModel> aliveUnits, List<UnitModel> allUnits) {
    // Don't check victory until both teams have units
    final blueTotal = allUnits.where((u) => u.team == Team.blue).length;
    final redTotal = allUnits.where((u) => u.team == Team.red).length;

    if (blueTotal == 0 || redTotal == 0 || allUnits.length < 2) {
      return VictoryState(hasWinner: false);
    }

    // Victory condition 1: Flag capture (highest priority)
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

    // Victory condition 2: Total elimination
    // Only if both teams had units AND no more units can be spawned AND one team has no living units
    if (blueUnits.isEmpty && redUnits.isNotEmpty && _blueUnitsRemaining <= 0 && blueTotal > 0) {
      return VictoryState(
        hasWinner: true,
        winner: Team.red,
        reason: VictoryReason.elimination,
      );
    }

    if (redUnits.isEmpty && blueUnits.isNotEmpty && _redUnitsRemaining <= 0 && redTotal > 0) {
      return VictoryState(
        hasWinner: true,
        winner: Team.blue,
        reason: VictoryReason.elimination,
      );
    }

    // Victory condition 3: Captain elimination - only if both teams had captains
    final blueCaptains = blueUnits.where((u) => u.type == UnitType.captain).toList();
    final redCaptains = redUnits.where((u) => u.type == UnitType.captain).toList();
    final blueCaptainsTotal = allUnits.where((u) => u.team == Team.blue && u.type == UnitType.captain).length;
    final redCaptainsTotal = allUnits.where((u) => u.team == Team.red && u.type == UnitType.captain).length;

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

  /// Calculate team health percentage
  static double calculateTeamHealth(List<UnitModel> units, Team team) {
    final teamUnits = units.where((u) => u.team == team).toList();
    if (teamUnits.isEmpty) return 0.0;

    double totalHealth = teamUnits.fold(0.0, (sum, unit) => sum + unit.health);
    double maxHealth = teamUnits.fold(0.0, (sum, unit) => sum + unit.maxHealth);

    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }
}

/// Game state result from rules processing
class GameState {
  VictoryState victoryState = VictoryState(hasWinner: false);
  List<String> unitsToRemove = [];
  int blueUnits = 0;
  int redUnits = 0;
  double blueHealthPercent = 1.0;
  double redHealthPercent = 1.0;
  int blueUnitsRemaining = kTotalUnitsPerTeam;
  int redUnitsRemaining = kTotalUnitsPerTeam;
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