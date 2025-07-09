// lib/ai/ai_service.dart
import 'dart:async';
import '../game/island_game.dart';
import '../services/game_command_manager.dart';
import '../models/unit_model.dart';
import '../models/ship_model.dart';
import '../utils/app_logger.dart';
import 'ai_player.dart';

class AIService {
  final IslandGame game;
  final GameCommandManager? commandManager;
  
  AIPlayer? _aiPlayer;
  bool _isEnabled = false;
  
  AIService({
    required this.game,
    this.commandManager,
  });

  /// Enable AI player
  void enableAI({
    Team aiTeam = Team.red,
    AIDifficulty difficulty = AIDifficulty.medium,
  }) {
    if (_isEnabled) return;
    
    _aiPlayer = AIPlayer(
      playerId: '${aiTeam.name}_ai',
      team: aiTeam,
      difficulty: difficulty,
      sendCommand: _sendAICommand,
      getGameState: _getGameStateForAI,
    );
    
    _aiPlayer!.start();
    _isEnabled = true;
    
    AppLogger.debug('AI enabled for team: $aiTeam, difficulty: $difficulty');
  }

  /// Disable AI player
  void disableAI() {
    if (!_isEnabled) return;
    
    _aiPlayer?.stop();
    _aiPlayer = null;
    _isEnabled = false;
    
    AppLogger.debug('AI disabled');
  }

  /// Send AI command through the game's command system
  void _sendAICommand(String commandType, Map<String, dynamic> data) {
    try {
      switch (commandType) {
        case 'spawn_unit':
          _handleSpawnUnit(data);
          break;
        case 'move_unit':
          _handleMoveUnit(data);
          break;
        case 'attack_unit':
          _handleAttackUnit(data);
          break;
        case 'unit_to_ship':
          _handleUnitToShip(data);
          break;
        case 'move_ship':
          _handleMoveShip(data);
          break;
        default:
          AppLogger.debug('Unknown AI command: $commandType');
      }
    } catch (e) {
      AppLogger.error('AI command error: $commandType', e);
    }
  }

  /// Handle AI unit spawning
  void _handleSpawnUnit(Map<String, dynamic> data) {
    final shipId = data['ship_id'] as String?;
    final unitTypeStr = data['unit_type'] as String?;
    final teamStr = data['team'] as String?;
    
    if (shipId == null || unitTypeStr == null || teamStr == null) return;
    
    final unitType = UnitType.values.firstWhere(
      (type) => type.name == unitTypeStr,
      orElse: () => UnitType.swordsman,
    );
    
    final team = Team.values.firstWhere(
      (t) => t.name == teamStr,
      orElse: () => Team.red,
    );
    
    // Find the ship and spawn unit
    final ship = game.getAllShips().firstWhere(
      (s) => s.model.id == shipId,
      orElse: () => null,
    );
    
    if (ship != null && ship.model.canSpawnUnit()) {
      game.spawnUnitFromShip(unitType, team, ship);
      AppLogger.debug('AI spawned $unitType from ship $shipId');
    }
  }

  /// Handle AI unit movement
  void _handleMoveUnit(Map<String, dynamic> data) {
    final unitId = data['unit_id'] as String?;
    final targetX = data['target_x'] as double?;
    final targetY = data['target_y'] as double?;
    
    if (unitId == null || targetX == null || targetY == null) return;
    
    final unit = game.getAllUnits().firstWhere(
      (u) => u.model.id == unitId,
      orElse: () => null,
    );
    
    if (unit != null && unit.model.team == _aiPlayer?.team) {
      unit.setTargetPosition(Vector2(targetX, targetY));
      AppLogger.debug('AI moved unit $unitId to ($targetX, $targetY)');
    }
  }

  /// Handle AI unit attack
  void _handleAttackUnit(Map<String, dynamic> data) {
    final attackerId = data['attacker_id'] as String?;
    final targetId = data['target_id'] as String?;
    
    if (attackerId == null || targetId == null) return;
    
    final attacker = game.getAllUnits().firstWhere(
      (u) => u.model.id == attackerId,
      orElse: () => null,
    );
    
    final target = game.getAllUnits().firstWhere(
      (u) => u.model.id == targetId,
      orElse: () => null,
    );
    
    if (attacker != null && target != null && 
        attacker.model.team == _aiPlayer?.team &&
        target.model.team != _aiPlayer?.team) {
      attacker.model.setTargetEnemy(target.model, playerInitiated: false);
      attacker.setTargetPosition(target.position);
      AppLogger.debug('AI ordered attack: $attackerId -> $targetId');
    }
  }

  /// Handle AI unit to ship command
  void _handleUnitToShip(Map<String, dynamic> data) {
    final unitId = data['unit_id'] as String?;
    final shipId = data['ship_id'] as String?;
    
    if (unitId == null || shipId == null) return;
    
    final unit = game.getAllUnits().firstWhere(
      (u) => u.model.id == unitId,
      orElse: () => null,
    );
    
    if (unit != null && unit.model.team == _aiPlayer?.team) {
      unit.model.seekSpecificShip(shipId);
      AppLogger.debug('AI sent unit $unitId to ship $shipId for healing');
    }
  }

  /// Handle AI ship movement
  void _handleMoveShip(Map<String, dynamic> data) {
    final shipId = data['ship_id'] as String?;
    final targetX = data['target_x'] as double?;
    final targetY = data['target_y'] as double?;
    
    if (shipId == null || targetX == null || targetY == null) return;
    
    final ship = game.getAllShips().firstWhere(
      (s) => s.model.id == shipId,
      orElse: () => null,
    );
    
    if (ship != null && ship.model.team == _aiPlayer?.team) {
      ship.setTargetPosition(Vector2(targetX, targetY));
      AppLogger.debug('AI moved ship $shipId to ($targetX, $targetY)');
    }
  }

  /// Get game state information for AI decision making
  Map<String, dynamic> _getGameStateForAI() {
    final allUnits = game.getAllUnits();
    final allShips = game.getAllShips();
    final apex = game.getIslandApex();
    
    return {
      'units': allUnits.map((u) => _unitToMap(u)).toList(),
      'ships': allShips.map((s) => _shipToMap(s)).toList(),
      'apex': apex != null ? {'x': apex.dx, 'y': apex.dy} : null,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Convert unit to map for AI processing
  Map<String, dynamic> _unitToMap(dynamic unit) {
    final model = unit.model;
    return {
      'id': model.id,
      'type': model.type.name,
      'team': model.team.name,
      'position': {'x': model.position.x, 'y': model.position.y},
      'health': model.health,
      'maxHealth': model.maxHealth,
      'state': model.state.name,
      'isInCombat': model.isInCombat,
      'isBoarded': model.isBoarded,
    };
  }

  /// Convert ship to map for AI processing
  Map<String, dynamic> _shipToMap(dynamic ship) {
    final model = ship.model;
    return {
      'id': model.id,
      'team': model.team.name,
      'position': {'x': model.position.x, 'y': model.position.y},
      'canSpawnUnit': model.canSpawnUnit(),
      'canBoardUnit': model.canBoardUnit(),
      'cargo': {
        'captain': model.getCargo(UnitType.captain),
        'swordsman': model.getCargo(UnitType.swordsman),
        'archer': model.getCargo(UnitType.archer),
      },
    };
  }

  /// Check if AI is currently enabled
  bool get isEnabled => _isEnabled;
  
  /// Get current AI difficulty
  AIDifficulty? get difficulty => _aiPlayer?.difficulty;
  
  /// Get AI team
  Team? get aiTeam => _aiPlayer?.team;
}
