import '../models/unit_model.dart';

/// Handles victory condition checks
class VictoryConditions {
  /// Check if a team has won by planting a flag at the apex
  static bool checkFlagVictory(List<UnitModel> units) {
    for (final unit in units) {
      if (unit.type == UnitType.captain && unit.hasPlantedFlag) {
        return true;
      }
    }
    return false;
  }
  
  /// Check if a team has won by eliminating all enemy units
  static bool checkEliminationVictory(List<UnitModel> units, Team team) {
    // Check if any enemy units are still alive
    bool enemiesExist = false;
    bool enemiesAlive = false;
    
    for (final unit in units) {
      if (unit.team != team) {
        enemiesExist = true;
        if (unit.health > 0) {
          enemiesAlive = true;
          break;
        }
      }
    }
    
    // Victory if enemies existed but none are alive
    return enemiesExist && !enemiesAlive;
  }
  
  /// Get the winning team if there is one
  static Team? getWinningTeam(List<UnitModel> units) {
    // Check flag victory
    for (final unit in units) {
      if (unit.type == UnitType.captain && unit.hasPlantedFlag) {
        return unit.team;
      }
    }
    
    // Check elimination victory
    if (checkEliminationVictory(units, Team.blue)) {
      return Team.blue;
    }
    
    if (checkEliminationVictory(units, Team.red)) {
      return Team.red;
    }
    
    return null; // No winner yet
  }
}