// lib/services/game_command_processor.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:logger/logger.dart';
import '../models/game_command.dart';
import '../models/unit_model.dart';
import '../game/island_game.dart';
import '../game/unit_component.dart';
import '../game/ship_component.dart';
import '../utils/app_logger.dart';
import 'game_state_sync_service.dart';

final _log = Logger();

/// Processes game commands received from remote players
class GameCommandProcessor {
  final IslandGame game;
  
  // Track processed commands to prevent duplicates
  final Set<String> _processedCommands = <String>{};
  
  GameCommandProcessor(this.game);

  /// Process a command received from a remote player
  Future<bool> processCommand(GameCommand command) async {
    print('🎮 DEBUG: GameCommandProcessor.processCommand called');
    print('🎮 DEBUG: Command type: ${command.commandType}');
    print('🎮 DEBUG: Command player: ${command.playerId}');
    print('🎮 DEBUG: Command ID: ${command.commandId}');
    
    // Check if we've already processed this command
    if (_processedCommands.contains(command.commandId)) {
      print('🔄 DEBUG: Command already processed: ${command.commandId}');
      _log.d('🔄 Command already processed: ${command.commandId}');
      return false;
    }

    try {
      bool success = false;
      
      print('🎮 DEBUG: Processing command type: ${command.commandType}');
      switch (command.commandType) {
        case 'unit_move':
          success = await _processUnitMoveCommand(command as UnitMoveCommand);
          break;
        case 'unit_spawn':
          success = await _processUnitSpawnCommand(command as UnitSpawnCommand);
          break;
        case 'unit_attack':
          success = await _processUnitAttackCommand(command as UnitAttackCommand);
          break;
        case 'unit_death':
          success = await _processUnitDeathCommand(command);
          break;
        case 'ship_move':
          success = await _processShipMoveCommand(command as ShipMoveCommand);
          break;
        case 'ship_deploy':
          success = await _processShipDeployCommand(command as ShipDeployCommand);
          break;
        case 'unit_board_ship':
          success = await _processUnitBoardShipCommand(command as UnitBoardShipCommand);
          break;
        case 'flag_raise':
          success = await _processFlagRaiseCommand(command as FlagRaiseCommand);
          break;
        default:
          print('❓ DEBUG: Unknown command type: ${command.commandType}');
          _log.w('❓ Unknown command type: ${command.commandType}');
          return false;
      }

      print('🎮 DEBUG: Command processing result: $success');
      if (success) {
        _processedCommands.add(command.commandId);
        print('✅ DEBUG: Successfully processed ${command.commandType} from ${command.playerId}');
        _log.d('✅ Processed command: ${command.commandType} from ${command.playerId}');
      } else {
        print('❌ DEBUG: Failed to process ${command.commandType}');
        _log.w('❌ Failed to process command: ${command.commandType}');
      }

      return success;
    } catch (e) {
      print('💥 DEBUG: Error processing command: $e');
      _log.e('💥 Error processing command: $e');
      return false;
    }
  }

  /// Process unit movement command
  Future<bool> _processUnitMoveCommand(UnitMoveCommand command) async {
    final units = _findUnitsByIds(command.unitIds);
    if (units.isEmpty) {
      _log.w('🚫 No units found for move command: ${command.unitIds}');
      return false;
    }

    // Verify units belong to the command sender
    final validUnits = units.where((unit) => 
      unit.model.playerId == command.playerId
    ).toList();

    if (validUnits.isEmpty) {
      _log.w('🚫 No valid units for player ${command.playerId}');
      return false;
    }

    // Convert island-relative coordinates back to world coordinates
    final worldTargetPosition = game.islandRelativeToWorld(command.targetPosition);
    
    print('🎯 DEBUG: Unit move - Relative target: (${command.targetPosition.x}, ${command.targetPosition.y})');
    print('🎯 DEBUG: Unit move - World target: (${worldTargetPosition.x}, ${worldTargetPosition.y})');
    
    _log.d('🎮 Moving ${validUnits.length} units to (${worldTargetPosition.x}, ${worldTargetPosition.y})');

    // Calculate formation positions using world coordinates
    final positions = _calculateFormationPositions(
      worldTargetPosition, 
      validUnits.length
    );

    // Move units to their positions
    for (int i = 0; i < validUnits.length; i++) {
      final unit = validUnits[i];
      final targetPos = i < positions.length ? positions[i] : worldTargetPosition;
      
      // Apply the movement
      unit.setTargetPosition(targetPos);
      unit.model.forceRedirect = true;
      
      // If this is an attack move, clear current targets
      if (command.isAttackMove) {
        unit.model.targetEnemy = null;
      }
    }

    return true;
  }

  /// Process unit spawn command
  Future<bool> _processUnitSpawnCommand(UnitSpawnCommand command) async {
    final ship = _findShipById(command.shipId);
    if (ship == null) {
      _log.w('🚫 Ship not found: ${command.shipId}');
      return false;
    }

    // Convert ship team to player ID for verification
    final shipPlayerId = ship.model.team == Team.blue ? 'blue' : 'red';
    
    // Verify ship belongs to command sender
    if (shipPlayerId != command.playerId) {
      print('🚫 DEBUG: Ship team ($shipPlayerId) does not match command player (${command.playerId})');
      _log.w('🚫 Ship does not belong to player ${command.playerId}');
      return false;
    }

    // Convert island-relative coordinates back to world coordinates
    final worldSpawnPosition = game.islandRelativeToWorld(command.spawnPosition);
    
    print('🆕 DEBUG: Processing unit spawn command for ${command.unitType}');
    print('🆕 DEBUG: Ship: ${command.shipId}, Player: ${command.playerId}');
    print('🆕 DEBUG: Relative position: (${command.spawnPosition.x}, ${command.spawnPosition.y})');
    print('🆕 DEBUG: World position: (${worldSpawnPosition.x}, ${worldSpawnPosition.y})');
    
    _log.d('🆕 Spawning ${command.unitType} at (${worldSpawnPosition.x}, ${worldSpawnPosition.y})');

    // Spawn the unit at the specified position using world coordinates
    // Note: We don't modify ship cargo here since that was already done on the sending device
    final team = ship.model.team;
    game.spawnUnitAtPosition(command.unitType, team, worldSpawnPosition);

    return true;
  }

  /// Process unit death command
  Future<bool> _processUnitDeathCommand(GameCommand command) async {
    final deathCommand = command as UnitDeathCommand;
    final unitId = deathCommand.unitId;
    
    if (unitId.isEmpty) {
      AppLogger.error('Unit death command missing unitId');
      return false;
    }

    final unit = _findUnitById(unitId);
    if (unit != null) {
      // Remove the unit from the game
      unit.removeFromParent();
      AppLogger.debug('Removed dead unit: $unitId');
      return true;
    } else {
      // Unit already removed or doesn't exist
      AppLogger.debug('Unit death command for already removed unit: $unitId');
      return true; // Not an error, just already handled
    }
  }

  /// Process unit attack command
  Future<bool> _processUnitAttackCommand(UnitAttackCommand command) async {
    final attacker = _findUnitById(command.attackerUnitId);
    final target = _findUnitById(command.targetUnitId);

    if (attacker == null || target == null) {
      _log.w('🚫 Units not found for attack: ${command.attackerUnitId} -> ${command.targetUnitId}');
      return false;
    }

    // Verify attacker belongs to command sender
    if (attacker.model.playerId != command.playerId) {
      _log.w('🚫 Attacker does not belong to player ${command.playerId}');
      return false;
    }

    // Verify units are on different teams
    if (attacker.model.team == target.model.team) {
      _log.w('🚫 Cannot attack friendly unit');
      return false;
    }

    _log.d('⚔️ ${command.attackerUnitId} attacking ${command.targetUnitId}');

    // Set the target enemy with player initiation flag
    attacker.model.setTargetEnemy(
      target.model, 
      playerInitiated: command.isPlayerInitiated
    );

    // Move toward target
    attacker.setTargetPosition(target.position);
    attacker.model.forceRedirect = true;

    return true;
  }

  /// Process ship movement command
  Future<bool> _processShipMoveCommand(ShipMoveCommand command) async {
    print('🚢 DEBUG: Processing ship move command for ${command.shipId}');
    
    final ship = _findShipById(command.shipId);
    if (ship == null) {
      print('🚫 DEBUG: Ship not found: ${command.shipId}');
      _log.w('🚫 Ship not found: ${command.shipId}');
      return false;
    }

    // Convert team to player ID for verification
    final shipTeam = ship.model.team == Team.blue ? 'blue' : 'red';
    
    // Verify ship belongs to command sender
    if (shipTeam != command.playerId) {
      print('🚫 DEBUG: Ship team ($shipTeam) does not match command player (${command.playerId})');
      _log.w('🚫 Ship does not belong to player ${command.playerId}');
      return false;
    }

    // Convert island-relative coordinates back to world coordinates
    final worldTargetPosition = game.islandRelativeToWorld(command.targetPosition);
    
    print('🚢 DEBUG: Relative target: (${command.targetPosition.x}, ${command.targetPosition.y})');
    print('🚢 DEBUG: World target: (${worldTargetPosition.x}, ${worldTargetPosition.y})');
    print('🚢 DEBUG: Moving ship ${command.shipId} to world position');
    _log.d('🚢 Moving ship ${command.shipId} to (${worldTargetPosition.x}, ${worldTargetPosition.y})');

    // Move the ship using world coordinates
    ship.setTargetPosition(worldTargetPosition);

    return true;
  }

  /// Process ship deploy command
  Future<bool> _processShipDeployCommand(ShipDeployCommand command) async {
    final ship = _findShipById(command.shipId);
    if (ship == null) {
      _log.w('🚫 Ship not found: ${command.shipId}');
      return false;
    }

    // Verify ship belongs to command sender
    if (ship.model.team.name != command.playerId) {
      _log.w('🚫 Ship does not belong to player ${command.playerId}');
      return false;
    }

    _log.d('🚢 Deploying ${command.unitType} from ship ${command.shipId}');

    // Use the game's existing deployment logic
    final success = game.deployUnitFromShip(command.unitType, ship.model.team);
    
    return success;
  }

  /// Process unit board ship command
  Future<bool> _processUnitBoardShipCommand(UnitBoardShipCommand command) async {
    final ship = _findShipById(command.shipId);
    if (ship == null) {
      _log.w('🚫 Ship not found: ${command.shipId}');
      return false;
    }

    final units = _findUnitsByIds(command.unitIds);
    if (units.isEmpty) {
      _log.w('🚫 No units found for boarding: ${command.unitIds}');
      return false;
    }

    // Verify units belong to command sender and same team as ship
    final validUnits = units.where((unit) => 
      unit.model.playerId == command.playerId &&
      unit.model.team == ship.model.team
    ).toList();

    if (validUnits.isEmpty) {
      _log.w('🚫 No valid units for boarding');
      return false;
    }

    _log.d('🚢 ${validUnits.length} units boarding ship ${command.shipId}');

    // Order units to board the ship
    for (final unit in validUnits) {
      if (ship.model.canBoardUnit()) {
        unit.model.setTargetShip(command.shipId);
      }
    }

    return true;
  }

  /// Process flag raise command
  Future<bool> _processFlagRaiseCommand(FlagRaiseCommand command) async {
    final captain = _findUnitById(command.captainUnitId);
    if (captain == null) {
      _log.w('🚫 Captain not found: ${command.captainUnitId}');
      return false;
    }

    // Verify captain belongs to command sender
    if (captain.model.playerId != command.playerId) {
      _log.w('🚫 Captain does not belong to player ${command.playerId}');
      return false;
    }

    // Verify it's actually a captain
    if (captain.model.type != UnitType.captain) {
      _log.w('🚫 Unit is not a captain: ${command.captainUnitId}');
      return false;
    }

    _log.d('🏴 Captain ${command.captainUnitId} raising flag at apex');

    // Move captain to apex and start flag raising
    captain.setTargetPosition(command.apexPosition);
    captain.model.forceRedirect = true;

    // The flag raising will be handled automatically when the captain reaches the apex
    // due to the existing game logic in UnitModel.update()

    return true;
  }

  /// Helper: Find unit by ID with fallback sync
  UnitComponent? _findUnitById(String unitId) {
    final units = game.getAllUnits();
    for (final unit in units) {
      if (unit.model.id == unitId && unit.model.health > 0) {
        return unit;
      }
    }
    
    // Unit not found - this could indicate desync
    AppLogger.warning('Unit not found: $unitId - possible desync detected');
    
    // Report desync to sync service
    try {
      final syncService = GameStateSyncService.instance;
      syncService.reportDesyncDetected('Unit not found: $unitId');
    } catch (e) {
      // Sync service might not be initialized yet
      AppLogger.debug('Could not report desync to sync service: $e');
    }
    
    return null;
  }

  /// Send unit death command when a unit dies
  Future<void> _sendUnitDeathCommand(String unitId, String playerId) async {
    try {
      final command = UnitDeathCommand(
        commandId: 'death_${unitId}_${DateTime.now().millisecondsSinceEpoch}',
        playerId: playerId,
        unitId: unitId,
        reason: 'combat',
      );
      
      // We need to get the GameCommandManager instance to send the command
      // For now, just log it - this method might not be used directly
      AppLogger.debug('Unit death command created for: $unitId');
    } catch (e) {
      AppLogger.error('Failed to create unit death command', e);
    }
  }

  /// Helper: Find multiple units by IDs
  List<UnitComponent> _findUnitsByIds(List<String> unitIds) {
    final units = game.getAllUnits();
    final foundUnits = <UnitComponent>[];
    
    for (final unitId in unitIds) {
      for (final unit in units) {
        if (unit.model.id == unitId && unit.model.health > 0) {
          foundUnits.add(unit);
          break;
        }
      }
    }
    
    return foundUnits;
  }

  /// Helper: Find ship by ID
  ShipComponent? _findShipById(String shipId) {
    final ships = game.getAllShips();
    for (final ship in ships) {
      if (ship.model.id == shipId && !ship.model.isDestroyed) {
        return ship;
      }
    }
    return null;
  }

  /// Helper: Calculate formation positions for multiple units
  List<Vector2> _calculateFormationPositions(Vector2 center, int unitCount) {
    if (unitCount <= 1) return [center];

    final positions = <Vector2>[];
    final spacing = 15.0;

    // Simple line formation for small groups
    if (unitCount <= 5) {
      final lineWidth = (unitCount - 1) * spacing;
      final startX = center.x - lineWidth / 2;

      for (int i = 0; i < unitCount; i++) {
        positions.add(Vector2(startX + i * spacing, center.y));
      }
      return positions;
    }

    // Circular formation for larger groups
    final radius = spacing * unitCount / (2 * 3.14159);
    for (int i = 0; i < unitCount; i++) {
      final angle = (i / unitCount) * 2 * 3.14159;
      final x = center.x + radius * math.cos(angle);
      final y = center.y + radius * math.sin(angle);
      positions.add(Vector2(x, y));
    }

    return positions;
  }

  /// Clear processed commands cache (call periodically to prevent memory leaks)
  void clearProcessedCommandsCache() {
    if (_processedCommands.length > 1000) {
      _processedCommands.clear();
      _log.d('🧹 Cleared processed commands cache');
    }
  }
}
