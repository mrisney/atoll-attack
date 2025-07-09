// lib/services/game_command_manager.dart
import 'package:flame/components.dart';
import '../models/game_command.dart';
import '../models/unit_model.dart';
import '../services/webrtc_game_service.dart';
import '../services/rtdb_service.dart';
import '../services/game_command_processor.dart';
import '../services/game_state_sync_service.dart';
import '../game/island_game.dart';
import '../game/unit_component.dart';
import '../game/ship_component.dart';
import '../utils/app_logger.dart';
import 'dart:async' as async;

/// Manages game commands using WebRTC (primary) + Firebase RTDB (fallback)
/// Leverages existing optimized RTDB service for reliability
class GameCommandManager {
  final IslandGame game;
  final String localPlayerId;
  late final GameCommandProcessor _processor;
  
  // Singleton pattern
  static GameCommandManager? _instance;
  static GameCommandManager get instance {
    if (_instance == null) {
      throw StateError('GameCommandManager not initialized. Call initialize() first.');
    }
    return _instance!;
  }
  
  static void initializeManager(IslandGame game, String playerId) {
    _instance = GameCommandManager._(game, playerId);
  }
  
  // Private constructor
  GameCommandManager._(this.game, this.localPlayerId) {
    _processor = GameCommandProcessor(game);
    _setupWebRTCListener();
    _setupRTDBListener();
    _startPeriodicSync();
    _startWebRTCHealthMonitoring();
    AppLogger.game('GameCommandManager initialized for player: $localPlayerId');
  }
  
  // Services
  final FirebaseRTDBService _rtdbService = FirebaseRTDBService.instance;
  
  // Subscriptions
  async.StreamSubscription? _rtdbSubscription;
  async.Timer? _periodicSyncTimer;
  async.Timer? _webrtcHealthTimer;
  bool _webrtcHealthy = true;
  
  // Command ID generation
  int _commandCounter = 0;
  
  GameCommandManager({
    required this.game,
    required this.localPlayerId,
  }) {
    _processor = GameCommandProcessor(game);
    print('🎮 DEBUG: GameCommandManager initialized for player: $localPlayerId');
  }

  /// Initialize with room code for both WebRTC and RTDB
  Future<void> initialize(String roomCode) async {
    print('🔧 DEBUG: Initializing command manager with room: $roomCode');
    
    // Initialize RTDB service
    try {
      await _rtdbService.initialize(roomCode);
      print('🔥 DEBUG: RTDB service initialized');
      _setupRTDBListener();
    } catch (e) {
      print('💥 DEBUG: RTDB initialization failed: $e');
      AppLogger.error('RTDB initialization failed', e);
    }
    
    // Initialize GameStateSyncService
    try {
      GameStateSyncService.initialize(game, localPlayerId);
      await GameStateSyncService.instance.initializeWithRoom(roomCode);
      print('🔄 DEBUG: GameStateSyncService initialized');
    } catch (e) {
      print('💥 DEBUG: GameStateSyncService initialization failed: $e');
      AppLogger.error('GameStateSyncService initialization failed', e);
    }
    
    // Set up WebRTC listener
    _setupWebRTCListener();
    
    print('✅ DEBUG: Command manager fully initialized');
  }

  /// Set up WebRTC command listener (primary channel)
  void _setupWebRTCListener() {
    final webrtcService = WebRTCGameService.instance;
    
    webrtcService.onGameCommand = (Map<String, dynamic> commandData) {
      try {
        AppLogger.webrtc('WebRTC command received: ${commandData['commandType']}');
        final command = GameCommand.fromJson(commandData);
        
        // Don't process our own commands
        if (command.playerId == localPlayerId) {
          AppLogger.debug('Ignoring own WebRTC command');
          return;
        }
        
        AppLogger.debug('Processing WebRTC command: ${command.commandType}');
        _processor.processCommand(command);
      } catch (e) {
        AppLogger.error('Error processing WebRTC command', e);
      }
    };
    
    print('📡 DEBUG: WebRTC listener configured');
  }

  /// Set up RTDB command listener (fallback channel)
  void _setupRTDBListener() {
    _rtdbSubscription = _rtdbService.commandStream.listen((rtdbCommand) {
      try {
        // Convert RTDB command format to GameCommand
        final commandType = rtdbCommand['type'] as String;
        final rawPayload = rtdbCommand['payload'];
        final senderId = rtdbCommand['sender_id'] as String;
        
        // Safely convert payload to Map<String, dynamic>
        final payload = _convertToStringDynamicMap(rawPayload);
        
        AppLogger.multiplayer('RTDB command received: $commandType from $senderId');
        
        // Skip non-game commands
        // Handle sync requests
        if (commandType == 'request_sync') {
          AppLogger.multiplayer('Received sync request from $senderId');
          // TODO: Implement sync when architecture is ready
          return;
        }
        
        if (!_isGameCommand(commandType)) {
          AppLogger.debug('Skipping non-game command: $commandType');
          return;
        }
        
        // Convert to GameCommand format
        final gameCommand = _convertRTDBToGameCommand(commandType, payload, senderId);
        if (gameCommand != null) {
          AppLogger.debug('Processing RTDB command: ${gameCommand.commandType}');
          _processor.processCommand(gameCommand);
        }
      } catch (e) {
        AppLogger.error('Error processing RTDB command', e);
      }
    });
    
    AppLogger.multiplayer('RTDB listener configured');
  }

  /// Safely convert Firebase data to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final stringKey = key.toString();
        if (value is Map) {
          result[stringKey] = _convertToStringDynamicMap(value);
        } else if (value is List) {
          result[stringKey] = value.map((item) => 
            item is Map ? _convertToStringDynamicMap(item) : item).toList();
        } else {
          result[stringKey] = value;
        }
      });
      return result;
    }
    return <String, dynamic>{'data': data};
  }

  /// Check if this is a game command (not ping/pong/join/leave)
  bool _isGameCommand(String commandType) {
    return !['ping', 'pong', 'join', 'leave'].contains(commandType);
  }

  /// Convert RTDB command format to GameCommand
  GameCommand? _convertRTDBToGameCommand(String type, Map<String, dynamic> payload, String senderId) {
    try {
      // Map RTDB command types to GameCommand types
      final commandData = <String, dynamic>{
        'commandId': payload['commandId'] ?? '${type}_${DateTime.now().millisecondsSinceEpoch}',
        'commandType': type,
        'playerId': _mapSenderToPlayerId(senderId),
        ...payload,
      };
      
      return GameCommand.fromJson(commandData);
    } catch (e) {
      print('💥 DEBUG: Error converting RTDB command: $e');
      return null;
    }
  }

  /// Map RTDB sender ID to player ID
  String _mapSenderToPlayerId(String senderId) {
    // For now, assume sender ID maps to player ID
    // You might need more sophisticated mapping based on your setup
    return senderId.contains('blue') ? 'blue' : 'red';
  }

  /// Send command via both WebRTC (primary) and RTDB (fallback)
  Future<void> _sendCommand(GameCommand command) async {
    print('📤 DEBUG: Sending command: ${command.commandType} (${command.commandId})');
    
    bool sentViaWebRTC = false;
    
    // Try WebRTC first (low latency)
    final webrtcService = WebRTCGameService.instance;
    if (webrtcService.isConnected) {
      try {
        await webrtcService.sendGameCommand(command.toJson());
        sentViaWebRTC = true;
        print('📡 DEBUG: Command sent via WebRTC');
      } catch (e) {
        print('⚠️ DEBUG: WebRTC send failed: $e');
      }
    }
    
    // Always send via RTDB as backup (and for reliability)
    try {
      final payload = command.toJson();
      payload.remove('commandType'); // RTDB uses separate type field
      
      await _rtdbService.sendCommand(command.commandType, payload);
      print('🔥 DEBUG: Command sent via RTDB');
    } catch (e) {
      print('💥 DEBUG: RTDB send failed: $e');
      AppLogger.error('RTDB send failed', e);
    }
    
    if (!sentViaWebRTC) {
      print('⚠️ DEBUG: Command sent via RTDB only (WebRTC unavailable)');
    }
  }

  /// Generate unique command ID
  String _generateCommandId() {
    return '${localPlayerId}_${DateTime.now().millisecondsSinceEpoch}_${++_commandCounter}';
  }

  /// Helper to check if ship belongs to local player
  bool _isLocalPlayerShip(ShipComponent ship) {
    final shipTeam = ship.model.team;
    
    // Handle different player ID formats
    if (localPlayerId == 'blue' || localPlayerId == 'red') {
      // Direct team matching
      final expectedTeam = localPlayerId == 'blue' ? Team.blue : Team.red;
      return shipTeam == expectedTeam;
    }
    
    // For generated player IDs, determine team based on WebRTC role
    final webrtcService = WebRTCGameService.instance;
    if (webrtcService.isHost) {
      // Host controls blue team
      return shipTeam == Team.blue;
    } else {
      // Guest controls red team  
      return shipTeam == Team.red;
    }
  }

  /// Helper to get local player team name
  String _getLocalPlayerTeam() {
    if (localPlayerId == 'blue' || localPlayerId == 'red') {
      return localPlayerId;
    }
    
    // For generated player IDs, determine team based on WebRTC role
    final webrtcService = WebRTCGameService.instance;
    return webrtcService.isHost ? 'blue' : 'red';
  }

  /// Send ship move command
  Future<void> sendShipMoveCommand({
    required ShipComponent ship,
    required Vector2 targetPosition,
  }) async {
    // Check if this ship belongs to the local player
    if (!_isLocalPlayerShip(ship)) {
      print('🚢 DEBUG: Ship ${ship.model.id} does not belong to local player');
      return;
    }

    final localTeam = _getLocalPlayerTeam();
    
    // Convert world coordinates to island-relative coordinates for consistency across devices
    final relativeTargetPosition = game.worldToIslandRelative(targetPosition);
    
    print('🚢 DEBUG: Creating ship move command for ${ship.model.id}');
    print('🚢 DEBUG: World target: (${targetPosition.x}, ${targetPosition.y})');
    print('🚢 DEBUG: Relative target: (${relativeTargetPosition.x}, ${relativeTargetPosition.y})');

    final command = ShipMoveCommand(
      commandId: _generateCommandId(),
      playerId: localTeam, // Use team name for consistency
      shipId: ship.model.id,
      targetPosition: relativeTargetPosition, // Send relative coordinates
    );

    print('🚢 DEBUG: Sending ship move command: ${command.toJson()}');
    await _sendCommand(command);
  }

  /// Send unit move command
  Future<void> sendUnitMoveCommand({
    required List<UnitComponent> units,
    required Vector2 targetPosition,
    bool isAttackMove = false,
  }) async {
    if (units.isEmpty) return;

    // Only send commands for units that belong to local player
    final localUnits = units.where((unit) => 
      unit.model.playerId == localPlayerId
    ).toList();

    if (localUnits.isEmpty) return;

    // Convert world coordinates to island-relative coordinates for consistency across devices
    final relativeTargetPosition = game.worldToIslandRelative(targetPosition);
    
    print('🎯 DEBUG: Unit move - World target: (${targetPosition.x}, ${targetPosition.y})');
    print('🎯 DEBUG: Unit move - Relative target: (${relativeTargetPosition.x}, ${relativeTargetPosition.y})');

    final command = UnitMoveCommand(
      commandId: _generateCommandId(),
      playerId: localPlayerId,
      unitIds: localUnits.map((unit) => unit.model.id).toList(),
      targetPosition: relativeTargetPosition, // Send relative coordinates
      isAttackMove: isAttackMove,
    );

    await _sendCommand(command);
  }

  /// Send unit spawn command
  Future<void> sendUnitSpawnCommand({
    required ShipComponent ship,
    required UnitType unitType,
    required Vector2 spawnPosition,
  }) async {
    // Check if this ship belongs to the local player
    if (!_isLocalPlayerShip(ship)) {
      print('🆕 DEBUG: Ship ${ship.model.id} does not belong to local player');
      return;
    }

    final localTeam = _getLocalPlayerTeam();
    
    // Convert world coordinates to island-relative coordinates
    final relativeSpawnPosition = game.worldToIslandRelative(spawnPosition);

    print('🆕 DEBUG: Sending unit spawn command for ${unitType}');
    print('🆕 DEBUG: Ship: ${ship.model.id}, Team: $localTeam');
    print('🆕 DEBUG: World position: (${spawnPosition.x}, ${spawnPosition.y})');
    print('🆕 DEBUG: Relative position: (${relativeSpawnPosition.x}, ${relativeSpawnPosition.y})');

    final command = UnitSpawnCommand(
      commandId: _generateCommandId(),
      playerId: localTeam, // Use team name for consistency
      shipId: ship.model.id,
      unitType: unitType,
      spawnPosition: relativeSpawnPosition, // Send relative coordinates
    );

    await _sendCommand(command);
  }

  /// Send unit attack command
  Future<void> sendUnitAttackCommand({
    required UnitComponent attacker,
    required UnitComponent target,
    bool isPlayerInitiated = false,
  }) async {
    // Verify attacker belongs to local player
    if (attacker.model.playerId != localPlayerId) return;

    final command = UnitAttackCommand(
      commandId: _generateCommandId(),
      playerId: localPlayerId,
      attackerUnitId: attacker.model.id,
      targetUnitId: target.model.id,
      isPlayerInitiated: isPlayerInitiated,
    );

    await _sendCommand(command);
  }

  /// Handle app lifecycle changes for sync
  void handleAppLifecycleChange(String state) {
    if (state == 'resumed') {
      AppLogger.game('App resumed, requesting game state sync');
      _requestGameStateSync();
    } else if (state == 'paused') {
      AppLogger.game('App paused, syncing current game state');
      _syncCurrentGameState();
    }
  }

  /// Request game state synchronization
  Future<void> _requestGameStateSync() async {
    try {
      await _rtdbService.requestGameStateSync();
      
      // Wait a moment then get the latest state
      await Future.delayed(const Duration(milliseconds: 500));
      final gameState = await _rtdbService.getGameState();
      
      if (gameState != null) {
        await _applyGameState(gameState);
      }
    } catch (e) {
      AppLogger.error('Failed to request game state sync', e);
    }
  }

  /// Sync current game state to RTDB
  Future<void> _syncCurrentGameState() async {
    try {
      // For now, just sync a basic state indicator
      // TODO: Implement full unit/ship sync when component APIs are stable
      final basicState = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'player': localPlayerId,
        'status': 'active',
      };
      
      await _rtdbService.syncGameState(
        units: [], // TODO: Extract units when component API is ready
        shipPositions: [], // TODO: Extract ships when component API is ready
        gamePhase: 'active',
      );
      
      AppLogger.game('Basic game state synced');
    } catch (e) {
      AppLogger.error('Failed to sync current game state', e);
    }
  }

  /// Apply synced game state to the current game
  Future<void> _applyGameState(Map<String, dynamic> gameState) async {
    try {
      AppLogger.game('Applying synced game state');
      
      // For now, just log the sync - full implementation when component APIs are ready
      final timestamp = gameState['timestamp'];
      AppLogger.game('Received game state from timestamp: $timestamp');
      
      // TODO: Implement full unit/ship sync when component APIs are stable
      
      AppLogger.game('Game state sync completed');
    } catch (e) {
      AppLogger.error('Failed to apply game state', e);
    }
  }

  /// Start periodic game state sync (every 30 seconds)
  void _startPeriodicSync() {
    _periodicSyncTimer = async.Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_webrtcHealthy) {
        // WebRTC is healthy, just sync to RTDB as backup
        _syncCurrentGameState();
      } else {
        // WebRTC is unhealthy, request full sync via RTDB
        AppLogger.warning('WebRTC unhealthy, requesting full sync via RTDB');
        _requestGameStateSync();
      }
    });
  }

  /// Monitor WebRTC health and fallback to RTDB when needed
  void _startWebRTCHealthMonitoring() {
    _webrtcHealthTimer = async.Timer.periodic(const Duration(seconds: 10), (timer) {
      final webrtcService = WebRTCGameService.instance;
      final wasHealthy = _webrtcHealthy;
      _webrtcHealthy = webrtcService.isConnected;
      
      if (wasHealthy && !_webrtcHealthy) {
        AppLogger.warning('WebRTC connection lost, falling back to RTDB');
        _requestGameStateSync();
      } else if (!wasHealthy && _webrtcHealthy) {
        AppLogger.info('WebRTC connection restored');
        _syncCurrentGameState();
      }
    });
  }

  /// Cleanup resources
  void dispose() {
    _rtdbSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _webrtcHealthTimer?.cancel();
    
    // Dispose sync service
    try {
      GameStateSyncService.instance.dispose();
    } catch (e) {
      AppLogger.debug('GameStateSyncService already disposed: $e');
    }
    
    AppLogger.game('GameCommandManager disposed');
  }

  /// Get connection status for debugging
  Map<String, dynamic> get connectionStatus {
    final webrtcService = WebRTCGameService.instance;
    return {
      'webrtc': {
        'connected': webrtcService.isConnected,
        'state': webrtcService.connectionState,
      },
      'rtdb': {
        'connected': _rtdbService.isConnected,
        'latency': _rtdbService.averageLatency,
      },
    };
  }
}
