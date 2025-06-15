import 'dart:async';
import 'package:flame/components.dart';
import '../models/unit_model.dart';

/// Service to manage game state and prepare for future multiplayer
class GameStateService {
  // Current game state
  List<UnitModel> _units = [];
  Team? _winningTeam;
  bool _gameOver = false;
  
  // Stream controllers for state updates
  final _unitsController = StreamController<List<UnitModel>>.broadcast();
  final _gameOverController = StreamController<Team?>.broadcast();
  
  // Streams that components can listen to
  Stream<List<UnitModel>> get unitsStream => _unitsController.stream;
  Stream<Team?> get gameOverStream => _gameOverController.stream;
  
  // Getters for current state
  List<UnitModel> get units => List.unmodifiable(_units);
  bool get isGameOver => _gameOver;
  Team? get winningTeam => _winningTeam;
  
  // Add a new unit
  void addUnit(UnitModel unit) {
    _units.add(unit);
    _unitsController.add(_units);
  }
  
  // Update a unit's state
  void updateUnit(String unitId, UnitModel updatedUnit) {
    final index = _units.indexWhere((u) => u.id == unitId);
    if (index >= 0) {
      _units[index] = updatedUnit;
      _unitsController.add(_units);
    }
  }
  
  // Remove a unit
  void removeUnit(String unitId) {
    _units.removeWhere((u) => u.id == unitId);
    _unitsController.add(_units);
  }
  
  // Set game over with winning team
  void setGameOver(Team winningTeam) {
    _gameOver = true;
    _winningTeam = winningTeam;
    _gameOverController.add(winningTeam);
  }
  
  // Reset game state
  void resetGame() {
    _units.clear();
    _gameOver = false;
    _winningTeam = null;
    _unitsController.add(_units);
    _gameOverController.add(null);
  }
  
  // Clean up resources
  void dispose() {
    _unitsController.close();
    _gameOverController.close();
  }
  
  // Future: methods for network synchronization
  Future<void> syncWithServer() async {
    // Will be implemented for multiplayer
  }
}