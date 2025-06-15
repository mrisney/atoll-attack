import '../models/unit_model.dart';

/// Handles victory condition checks with proper validation
class VictoryConditions {
  /// Check if a team has won by planting a flag at the apex
  static bool checkFlagVictory(List<UnitModel> units) {
    for (final unit in units) {
      if (unit.type == UnitType.captain &&
          unit.hasPlantedFlag &&
          unit.health > 0) {
        return true;
      }
    }
    return false;
  }

  /// Check if a team has won by eliminating all enemy units
  static bool checkEliminationVictory(List<UnitModel> units, Team team) {
    // Only check if the game has actually started (both teams have units)
    bool blueHasUnits = false;
    bool redHasUnits = false;
    bool blueHasAliveUnits = false;
    bool redHasAliveUnits = false;

    for (final unit in units) {
      if (unit.team == Team.blue) {
        blueHasUnits = true;
        if (unit.health > 0) {
          blueHasAliveUnits = true;
        }
      } else if (unit.team == Team.red) {
        redHasUnits = true;
        if (unit.health > 0) {
          redHasAliveUnits = true;
        }
      }
    }

    // Only declare victory if:
    // 1. Both teams have spawned units
    // 2. One team has no alive units
    // 3. The other team has at least one alive unit
    if (!blueHasUnits || !redHasUnits) {
      return false; // Game hasn't properly started
    }

    if (team == Team.blue) {
      return !redHasAliveUnits && blueHasAliveUnits;
    } else {
      return !blueHasAliveUnits && redHasAliveUnits;
    }
  }

  /// Get the winning team if there is one
  static Team? getWinningTeam(List<UnitModel> units) {
    // Ensure we have a minimum number of units before checking victory
    if (units.length < 2) {
      return null; // Not enough units to have a meaningful game
    }

    // Check flag victory first (highest priority)
    for (final unit in units) {
      if (unit.type == UnitType.captain &&
          unit.hasPlantedFlag &&
          unit.health > 0) {
        return unit.team;
      }
    }

    // Count alive units by team
    int blueAlive =
        units.where((u) => u.team == Team.blue && u.health > 0).length;
    int redAlive =
        units.where((u) => u.team == Team.red && u.health > 0).length;
    int blueTotal = units.where((u) => u.team == Team.blue).length;
    int redTotal = units.where((u) => u.team == Team.red).length;

    // Only check elimination if both teams have spawned units
    if (blueTotal == 0 || redTotal == 0) {
      return null; // Game hasn't properly started
    }

    // Check elimination victory
    if (blueAlive > 0 && redAlive == 0) {
      return Team.blue;
    }

    if (redAlive > 0 && blueAlive == 0) {
      return Team.red;
    }

    return null; // No winner yet
  }
}
