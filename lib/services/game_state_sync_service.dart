// lib/services/game_state_sync_service.dart
import 'dart:async' as async;
import 'dart:convert';
import 'package:flame/components.dart';
import '../models/unit_model.dart';
import '../models/ship_model.dart';
import '../game/island_game.dart';
import '../game/unit_component.dart';
import '../game/ship_component.dart';
import '../services/rtdb_service.dart';
import '../services/webrtc_game_service.dart';
import '../utils/app_logger.dart';

/// Comprehensive game state synchronization service
/// Handles periodic sync, conflict resolution, and desync recovery
class GameStateSyncService {
  final IslandGame game;
  final String localPlayerId;
  
  // Singleton pattern
  static GameStateSyncService? _instance;
  static GameStateSyncService get instance {
    if (_instance == null) {
      throw StateError('GameStateSyncService not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  static void initialize(IslandGame game, String playerId) {
    _instance = GameStateSyncService._(game, playerId);
  }
  
  GameStateSyncService._(this.game, this.localPlayerId);
  
  // Services
  final FirebaseRTDBService _rtdbService = FirebaseRTDBService.instance;
  
  // Sync timers and state
  async.Timer? _periodicSyncTimer;
  async.Timer? _healthCheckTimer;
  DateTime _lastFullSync = DateTime.now();
  bool _syncInProgress = false;
  int _desyncDetectionCount = 0;
  
  // Sync configuration
  static const Duration _periodicSyncInterval = Duration(seconds: 15);
  static const Duration _healthCheckInterval = Duration(seconds: 5);
  static const Duration _forceFullSyncInterval = Duration(minutes: 2);
  static const int _maxDesyncCount = 3;
  
  /// Initialize the sync service with room code
  Future<void> initializeWithRoom(String roomCode) async {
    AppLogger.game('Initializing GameStateSyncService for room: $roomCode');
    
    _startPeriodicSync();
    _startHealthCheck();
    
    // Initial sync after a short delay
    async.Timer(const Duration(seconds: 2), () {
      _performFullSync();
    });
    
    AppLogger.game('GameStateSyncService initialized');
  }
  
  /// Start periodic full game state synchronization
  void _startPeriodicSync() {
    _periodicSyncTimer = async.Timer.periodic(_periodicSyncInterval, (timer) {
      if (!_syncInProgress) {
        _performIncrementalSync();
      }
    });
    
    AppLogger.game('Periodic sync started (${_periodicSyncInterval.inSeconds}s interval)');
  }
  
  /// Start health check for desync detection
  void _startHealthCheck() {
    _healthCheckTimer = async.Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
    
    AppLogger.game('Health check started (${_healthCheckInterval.inSeconds}s interval)');
  }
  
  /// Perform incremental sync (lightweight)
  Future<void> _performIncrementalSync() async {
    try {
      _syncInProgress = true;
      
      // Check if we need a full sync
      final timeSinceLastFullSync = DateTime.now().difference(_lastFullSync);
      if (timeSinceLastFullSync > _forceFullSyncInterval || _desyncDetectionCount >= _maxDesyncCount) {
        await _performFullSync();
        return;
      }
      
      // Incremental sync: just sync critical state changes
      await _syncCriticalState();
      
      AppLogger.debug('Incremental sync completed');
    } catch (e) {
      AppLogger.error('Incremental sync failed', e);
      _desyncDetectionCount++;
    } finally {
      _syncInProgress = false;
    }
  }
  
  /// Perform full game state synchronization
  Future<void> _performFullSync() async {
    try {
      _syncInProgress = true;
      AppLogger.game('Starting full game state sync');
      
      // Get current game state
      final currentState = _captureGameState();
      
      // Send our state to RTDB
      await _rtdbService.syncGameState(
        units: currentState['units'],
        shipPositions: currentState['ships'],
        gamePhase: currentState['gamePhase'],
      );
      
      // Wait a moment for other clients to sync
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Get the authoritative state from RTDB
      final authoritativeState = await _rtdbService.getGameState();
      
      if (authoritativeState != null) {
        await _applyAuthoritativeState(authoritativeState);
      }
      
      _lastFullSync = DateTime.now();
      _desyncDetectionCount = 0;
      
      AppLogger.game('Full game state sync completed');
    } catch (e) {
      AppLogger.error('Full sync failed', e);
      _desyncDetectionCount++;
    } finally {
      _syncInProgress = false;
    }
  }
  
  /// Sync only critical state changes (units that died, new units, etc.)
  Future<void> _syncCriticalState() async {
    final criticalState = _captureCriticalState();
    
    if (criticalState.isNotEmpty) {
      await _rtdbService.syncCriticalState(criticalState);
      AppLogger.debug('Critical state synced: ${criticalState.keys.join(', ')}');
    }
  }
  
  /// Capture complete current game state
  Map<String, dynamic> _captureGameState() {
    final units = game.getAllUnits();
    final ships = game.getAllShips();
    
    return {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'playerId': localPlayerId,
      'units': units.map((unit) => _serializeUnit(unit)).toList(),
      'ships': ships.map((ship) => _serializeShip(ship)).toList(),
      'gamePhase': 'active', // TODO: Add proper game phase tracking
      'checksum': _calculateStateChecksum(units, ships),
    };
  }
  
  /// Capture only critical state changes
  Map<String, dynamic> _captureCriticalState() {
    final units = game.getAllUnits();
    final deadUnits = units.where((unit) => unit.model.health <= 0).toList();
    final lowHealthUnits = units.where((unit) => 
      unit.model.health > 0 && unit.model.health / unit.model.maxHealth < 0.3
    ).toList();
    
    final criticalState = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'playerId': localPlayerId,
    };
    
    if (deadUnits.isNotEmpty) {
      criticalState['deadUnits'] = deadUnits.map((unit) => unit.model.id).toList();
    }
    
    if (lowHealthUnits.isNotEmpty) {
      criticalState['lowHealthUnits'] = lowHealthUnits.map((unit) => {
        'id': unit.model.id,
        'health': unit.model.health,
        'maxHealth': unit.model.maxHealth,
      }).toList();
    }
    
    return criticalState;
  }
  
  /// Apply authoritative state from server
  Future<void> _applyAuthoritativeState(Map<String, dynamic> authoritativeState) async {
    AppLogger.game('Applying authoritative game state');
    
    try {
      // Safely convert Firebase data to proper types
      final safeAuthState = _convertFirebaseData(authoritativeState);
      
      // Get authoritative units and ships
      final authUnits = safeAuthState['units'] as List<dynamic>? ?? [];
      final authShips = safeAuthState['ships'] as List<dynamic>? ?? [];
      
      // Apply unit state
      await _applyUnitState(authUnits);
      
      // Apply ship state
      await _applyShipState(authShips);
      
      AppLogger.game('Authoritative state applied successfully');
    } catch (e) {
      AppLogger.error('Failed to apply authoritative state', e);
      throw e;
    }
  }
  
  /// Safely convert Firebase data types to Dart types
  Map<String, dynamic> _convertFirebaseData(dynamic data) {
    if (data == null) return <String, dynamic>{};
    
    if (data is Map<String, dynamic>) {
      return data;
    }
    
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final stringKey = key.toString();
        if (value is Map) {
          result[stringKey] = _convertFirebaseData(value);
        } else if (value is List) {
          result[stringKey] = value.map((item) => 
            item is Map ? _convertFirebaseData(item) : item).toList();
        } else {
          result[stringKey] = value;
        }
      });
      return result;
    }
    
    return <String, dynamic>{'data': data};
  }
  
  /// Apply authoritative unit state
  Future<void> _applyUnitState(List<dynamic> authUnits) async {
    final currentUnits = game.getAllUnits();
    final authUnitMap = <String, Map<String, dynamic>>{};
    
    // Build map of authoritative units with safe type conversion
    for (final unitData in authUnits) {
      final unitMap = _convertFirebaseData(unitData);
      final unitId = unitMap['id']?.toString();
      if (unitId != null) {
        authUnitMap[unitId] = unitMap;
      }
    }
    
    // Remove units that shouldn't exist
    final unitsToRemove = <UnitComponent>[];
    for (final unit in currentUnits) {
      if (!authUnitMap.containsKey(unit.model.id)) {
        unitsToRemove.add(unit);
        AppLogger.debug('Removing desync unit: ${unit.model.id}');
      }
    }
    
    for (final unit in unitsToRemove) {
      unit.removeFromParent();
    }
    
    // Update existing units and add missing ones
    for (final authUnitData in authUnitMap.values) {
      final unitId = authUnitData['id']?.toString();
      if (unitId == null) continue;
      
      final existingUnit = currentUnits.firstWhere(
        (unit) => unit.model.id == unitId,
        orElse: () => null as UnitComponent,
      );
      
      if (existingUnit != null) {
        // Update existing unit
        _updateUnitFromData(existingUnit, authUnitData);
      } else {
        // Create missing unit
        await _createUnitFromData(authUnitData);
      }
    }
  }
  
  /// Apply authoritative ship state
  Future<void> _applyShipState(List<dynamic> authShips) async {
    final currentShips = game.getAllShips();
    
    for (final shipData in authShips) {
      final shipMap = _convertFirebaseData(shipData);
      final shipId = shipMap['id']?.toString();
      if (shipId == null) continue;
      
      final existingShip = currentShips.firstWhere(
        (ship) => ship.model.id == shipId,
        orElse: () => null as ShipComponent,
      );
      
      if (existingShip != null) {
        _updateShipFromData(existingShip, shipMap);
      }
    }
  }
  
  /// Update unit from authoritative data
  void _updateUnitFromData(UnitComponent unit, Map<String, dynamic> data) {
    try {
      // Update critical properties with safe type conversion
      final health = data['health'];
      if (health != null) {
        unit.model.health = (health as num).toDouble();
      }
      
      final position = data['position'];
      if (position is Map) {
        final posMap = _convertFirebaseData(position);
        final x = posMap['x'];
        final y = posMap['y'];
        if (x != null && y != null) {
          unit.model.position = Vector2(
            (x as num).toDouble(),
            (y as num).toDouble(),
          );
        }
      }
      
      // Update state if significantly different
      final stateStr = data['state']?.toString();
      if (stateStr != null) {
        final authState = UnitState.values.firstWhere(
          (state) => state.name == stateStr,
          orElse: () => UnitState.idle,
        );
        
        if (unit.model.state != authState) {
          unit.model.state = authState;
          AppLogger.debug('Updated unit ${unit.model.id} state to $authState');
        }
      }
      
      // Handle combat state
      final targetEnemyId = data['targetEnemyId']?.toString();
      if (targetEnemyId != null && targetEnemyId.isNotEmpty) {
        final allUnits = game.getAllUnits();
        final targetUnit = allUnits.firstWhere(
          (u) => u.model.id == targetEnemyId,
          orElse: () => null as UnitComponent,
        );
        
        if (targetUnit != null) {
          unit.model.targetEnemy = targetUnit.model;
        }
      } else {
        unit.model.targetEnemy = null;
      }
    } catch (e) {
      AppLogger.error('Error updating unit ${unit.model.id} from data', e);
    }
  }
  
  /// Create unit from authoritative data
  Future<void> _createUnitFromData(Map<String, dynamic> data) async {
    try {
      final typeStr = data['type']?.toString();
      if (typeStr == null) return;
      
      final unitType = UnitType.values.firstWhere(
        (type) => type.name == typeStr,
        orElse: () => UnitType.swordsman,
      );
      
      final teamStr = data['team']?.toString();
      if (teamStr == null) return;
      
      final team = Team.values.firstWhere(
        (t) => t.name == teamStr,
        orElse: () => Team.blue,
      );
      
      final position = data['position'];
      if (position is! Map) return;
      
      final posMap = _convertFirebaseData(position);
      final x = posMap['x'];
      final y = posMap['y'];
      if (x == null || y == null) return;
      
      final spawnPosition = Vector2(
        (x as num).toDouble(),
        (y as num).toDouble(),
      );
      
      // Spawn the unit
      final newUnit = game.spawnUnitAtPosition(unitType, team, spawnPosition);
      
      // Update with authoritative data
      if (newUnit != null) {
        _updateUnitFromData(newUnit, data);
        AppLogger.debug('Created missing unit: ${data['id']}');
      }
    } catch (e) {
      AppLogger.error('Error creating unit from data', e);
    }
  }
  
  /// Update ship from authoritative data
  void _updateShipFromData(ShipComponent ship, Map<String, dynamic> data) {
    try {
      final position = data['position'];
      if (position is Map) {
        final posMap = _convertFirebaseData(position);
        final x = posMap['x'];
        final y = posMap['y'];
        if (x != null && y != null) {
          ship.model.position = Vector2(
            (x as num).toDouble(),
            (y as num).toDouble(),
          );
        }
      }
      
      // Update cargo if different
      final cargo = data['cargo'];
      if (cargo is Map) {
        final cargoMap = _convertFirebaseData(cargo);
        
        final captainCount = cargoMap['captain'];
        if (captainCount != null) {
          ship.model.setCargo(UnitType.captain, (captainCount as num).toInt());
        }
        
        final swordsmanCount = cargoMap['swordsman'];
        if (swordsmanCount != null) {
          ship.model.setCargo(UnitType.swordsman, (swordsmanCount as num).toInt());
        }
        
        final archerCount = cargoMap['archer'];
        if (archerCount != null) {
          ship.model.setCargo(UnitType.archer, (archerCount as num).toInt());
        }
      }
    } catch (e) {
      AppLogger.error('Error updating ship ${ship.model.id} from data', e);
    }
  }
  
  /// Serialize unit for sync
  Map<String, dynamic> _serializeUnit(UnitComponent unit) {
    return {
      'id': unit.model.id,
      'playerId': unit.model.playerId,
      'type': unit.model.type.name,
      'team': unit.model.team.name,
      'health': unit.model.health,
      'maxHealth': unit.model.maxHealth,
      'position': {
        'x': unit.model.position.x,
        'y': unit.model.position.y,
      },
      'state': unit.model.state.name,
      'targetEnemyId': unit.model.targetEnemy?.id,
      'isInCombat': unit.model.isInCombat,
      'isBoarded': unit.model.isBoarded,
    };
  }
  
  /// Serialize ship for sync
  Map<String, dynamic> _serializeShip(ShipComponent ship) {
    return {
      'id': ship.model.id,
      'team': ship.model.team.name,
      'position': {
        'x': ship.model.position.x,
        'y': ship.model.position.y,
      },
      'cargo': {
        'captain': ship.model.captainCargo,
        'swordsman': ship.model.swordsmanCargo,
        'archer': ship.model.archerCargo,
      },
    };
  }
  
  /// Calculate state checksum for desync detection
  String _calculateStateChecksum(List<UnitComponent> units, List<ShipComponent> ships) {
    final stateString = StringBuffer();
    
    // Add unit states
    for (final unit in units) {
      stateString.write('${unit.model.id}:${unit.model.health}:${unit.model.position.x.toInt()}:${unit.model.position.y.toInt()};');
    }
    
    // Add ship states
    for (final ship in ships) {
      stateString.write('${ship.model.id}:${ship.model.position.x.toInt()}:${ship.model.position.y.toInt()};');
    }
    
    return stateString.toString().hashCode.toString();
  }
  
  /// Perform health check to detect desyncs
  void _performHealthCheck() {
    try {
      final units = game.getAllUnits();
      final ships = game.getAllShips();
      
      // Check for obvious desync indicators
      final deadUnitsStillActive = units.where((unit) => unit.model.health <= 0).length;
      
      if (deadUnitsStillActive > 0) {
        AppLogger.warning('Health check: Found $deadUnitsStillActive dead units still active');
        _desyncDetectionCount++;
        
        // Clean up dead units immediately
        _cleanupDeadUnits();
      }
      
      // Check for units in impossible states
      final unitsInCombatWithoutTarget = units.where((unit) => 
        unit.model.isInCombat && unit.model.targetEnemy == null
      ).length;
      
      if (unitsInCombatWithoutTarget > 0) {
        AppLogger.warning('Health check: Found $unitsInCombatWithoutTarget units in combat without targets');
        _desyncDetectionCount++;
      }
      
      AppLogger.debug('Health check completed - Units: ${units.length}, Ships: ${ships.length}');
    } catch (e) {
      AppLogger.error('Health check failed', e);
    }
  }
  
  /// Clean up dead units that shouldn't exist
  void _cleanupDeadUnits() {
    final units = game.getAllUnits();
    final deadUnits = units.where((unit) => unit.model.health <= 0).toList();
    
    for (final deadUnit in deadUnits) {
      deadUnit.removeFromParent();
      AppLogger.debug('Cleaned up dead unit: ${deadUnit.model.id}');
    }
    
    if (deadUnits.isNotEmpty) {
      AppLogger.game('Cleaned up ${deadUnits.length} dead units');
    }
  }
  
  /// Handle desync detection from command failures
  void reportDesyncDetected(String reason) {
    AppLogger.warning('Desync detected: $reason');
    _desyncDetectionCount++;
    
    // Trigger immediate sync if too many desyncs
    if (_desyncDetectionCount >= _maxDesyncCount) {
      AppLogger.warning('Too many desyncs detected, triggering full sync');
      async.Timer(const Duration(milliseconds: 100), () {
        _performFullSync();
      });
    }
  }
  
  /// Force immediate full sync (for debugging or critical situations)
  Future<void> forceFullSync() async {
    AppLogger.game('Force full sync requested');
    await _performFullSync();
  }
  
  /// Get sync status for debugging
  Map<String, dynamic> get syncStatus {
    return {
      'lastFullSync': _lastFullSync.toIso8601String(),
      'syncInProgress': _syncInProgress,
      'desyncCount': _desyncDetectionCount,
      'timeSinceLastSync': DateTime.now().difference(_lastFullSync).inSeconds,
    };
  }
  
  /// Dispose of the service
  void dispose() {
    _periodicSyncTimer?.cancel();
    _healthCheckTimer?.cancel();
    AppLogger.game('GameStateSyncService disposed');
  }
}
