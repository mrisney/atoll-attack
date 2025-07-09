// lib/services/rtdb_service.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/app_logger.dart';
import '../models/unit_model.dart';

class FirebaseRTDBService {
  FirebaseRTDBService._();
  static final FirebaseRTDBService instance = FirebaseRTDBService._();

  final List<int> _rttSamples = [];
  late String _gameCode;
  String? _deviceId;
  late final FirebaseDatabase _db;

  // Command stream controller
  final StreamController<Map<String, dynamic>> _cmdCtrl =
      StreamController.broadcast();

  // Subscriptions
  StreamSubscription<DatabaseEvent>? _commandSubscription;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  bool _initialized = false;
  DatabaseReference? _gameRef;

  // Track processed commands to avoid duplicates
  final Set<String> _processedCommands = {};

  /// True once initialize() completes without error
  bool get isConnected => _initialized;

  /// Your last RTT in ms
  int? get lastRtt => _rttSamples.isEmpty ? null : _rttSamples.last;

  /// Average RTT
  double get avgRtt => _rttSamples.isEmpty
      ? 0
      : _rttSamples.reduce((a, b) => a + b) / _rttSamples.length;

  /// Average latency (alias for avgRtt)
  double get averageLatency => avgRtt;

  /// Get latest RTT samples (for display)
  List<int> get rttSamples => List.unmodifiable(_rttSamples);

  /// Command stream for listening to incoming commands
  Stream<Map<String, dynamic>> get commandStream => _cmdCtrl.stream;

  /// Get or create a unique device ID
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Create more unique device ID with timestamp
      final uuid = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      deviceId = '${uuid.substring(0, 8)}-$timestamp';
      await prefs.setString('device_id', deviceId);
      AppLogger.info('🆆 Generated new device ID: ${deviceId.substring(0, 12)}...');
    }

    _deviceId = deviceId;
    return deviceId;
  }

  /// Initialize the RTDB service for a game
  Future<void> initialize(String gameCode) async {
    _gameCode = gameCode;

    // Ensure we have a device ID
    await _getDeviceId();
    AppLogger.info(
        '🔧 Initializing RTDB with device ID: ${_deviceId?.substring(0, 8)}...');

    // Clear processed commands when reinitializing
    _processedCommands.clear();

    try {
      // Use Firebase Database instance (URL from firebase_options.dart)
      _db = FirebaseDatabase.instance;
      
      // Set up game reference
      _gameRef = _db.ref('games/$_gameCode');

      // Enable offline persistence (this is synchronous, not async)
      _db.setPersistenceEnabled(true);
      await _gameRef!.keepSynced(true);

      // Monitor connection state
      _connectionSubscription = _db.ref('.info/connected').onValue.listen(
        (event) {
          final connected = event.snapshot.value as bool? ?? false;
          AppLogger.info(
              '🔌 RTDB Connection: ${connected ? "Connected" : "Disconnected"} (initialized: $_initialized)');

          if (connected) {
            if (!_initialized) {
              _initialized = true;
              AppLogger.info('🎉 First connection established - sending join command');
              // Send join command when connected
              sendCommand('join', {
                'device_id': _deviceId,
                'timestamp': DateTime.now().toIso8601String(),
              });
            } else {
              AppLogger.info('🔄 Reconnected to RTDB');
            }
          } else {
            if (_initialized) {
              AppLogger.warning('⚠️ Lost RTDB connection');
            }
          }
        },
      );

      // Listen for new commands (optimized path)
      _commandSubscription = _gameRef!
          .child('cmd')
          .limitToLast(50) // limit to recent commands only
          .onChildAdded
          .listen(
        (event) {
          _handleCommand(event.snapshot);
        },
        onError: (error) {
          AppLogger.error('❌ Command subscription error: $error');
        },
      );

      AppLogger.info('✅ RTDB initialized for game $_gameCode');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize RTDB: $e');
      _initialized = false;
      rethrow;
    }
  }

  /// Handle incoming command
  void _handleCommand(DataSnapshot snapshot) {
    try {
      final key = snapshot.key;
      if (key == null || _processedCommands.contains(key)) {
        return; // Skip if already processed
      }

      _processedCommands.add(key);

      // Clean up old processed commands to prevent memory growth
      if (_processedCommands.length > 1000) {
        final toRemove = _processedCommands.take(500).toList();
        toRemove.forEach(_processedCommands.remove);
      }

      final data = snapshot.value as Map<Object?, Object?>?;
      if (data == null) return;

      // Convert to Map<String, dynamic> (optimized field names)
      final command = <String, dynamic>{};
      data.forEach((key, value) {
        if (key is String) {
          command[key] = value;
        }
      });

      final type = command['t'] as String? ?? command['type'] as String? ?? '';
      final senderId = command['s'] as String? ?? command['sender_id'] as String? ?? 'unknown';
      final payload = command['p'] as Map<Object?, Object?>? ?? command['payload'] as Map<Object?, Object?>? ?? {};

      // Convert payload to proper type
      final typedPayload = <String, dynamic>{};
      payload.forEach((key, value) {
        if (key is String) {
          typedPayload[key] = value;
        }
      });

      // Handle ping/pong for latency measurement (optimized)
      if (type == 'ping' && senderId != _deviceId?.substring(0, 8)) {
        // Respond to ping with minimal payload
        final pingTs = typedPayload['pts'] as int? ?? typedPayload['ping_ts'] as int? ?? 0;
        sendCommand('pong', {'pts': pingTs});
      } else if (type == 'pong' && senderId != _deviceId?.substring(0, 8)) {
        // Calculate RTT
        final pingTs = typedPayload['pts'] as int? ?? typedPayload['ping_ts'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final rtt = now - pingTs;

        _rttSamples.add(rtt);
        if (_rttSamples.length > 10) {
          _rttSamples.removeAt(0); // Keep last 10 samples
        }

        AppLogger.info(
            '🏓 Pong received, RTT = ${rtt}ms (avg: ${avgRtt.toStringAsFixed(1)}ms)');
      } else if (senderId != _deviceId) {
        // Forward other commands to the stream (skip our own commands)
        _cmdCtrl.add({
          'id': key,
          'type': type,
          'payload': typedPayload,
          'sender_id': senderId,
          'timestamp': command['timestamp'],
        });

        AppLogger.info(
            '📥 Command received: $type from ${senderId.substring(0, 8)}...');
      }
    } catch (e) {
      AppLogger.error('❌ Error handling command: $e');
    }
  }

  /// Send a command (optimized for low latency)
  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    if (!_initialized || _gameRef == null) {
      AppLogger.warning('⚠️ Cannot send command - not initialized');
      return;
    }

    final deviceId = await _getDeviceId();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // Minimize payload size for faster transmission
      final command = {
        't': type, // shortened field names
        'p': payload,
        's': deviceId.substring(0, 8), // shorter sender ID
        'ts': now,
      };

      // Add timestamp to payload for ping
      if (type == 'ping') {
        command['p'] = {'pts': now}; // minimal ping payload
      }

      // Use direct path write instead of push() for speed
      final commandRef = _gameRef!.child('cmd').child(now.toString());
      await commandRef.set(command);

      AppLogger.info('📤 Sent command: $type');
    } catch (e) {
      AppLogger.error('❌ Failed to send command "$type": $e');
    }
  }

  /// Send a ping to measure latency
  Future<void> sendPing() async {
    await sendCommand('ping', {});
  }

  /// Sync complete game state to Firebase RTDB
  Future<void> syncGameState({
    required List<Map<String, dynamic>> units,
    required List<Map<String, dynamic>> shipPositions,
    required String gamePhase,
  }) async {
    try {
      final gameState = {
        'units': units,
        'ships': shipPositions,
        'phase': gamePhase,
        'timestamp': ServerValue.timestamp,
        'synced_by': _deviceId,
      };

      await _db.ref('games/$_gameCode/state').set(gameState);
      AppLogger.multiplayer('Game state synced to RTDB');
    } catch (e) {
      AppLogger.error('Failed to sync game state', e);
    }
  }

  /// Sync critical state changes only
  Future<void> syncCriticalState(Map<String, dynamic> criticalState) async {
    try {
      final stateUpdate = {
        ...criticalState,
        'timestamp': ServerValue.timestamp,
        'synced_by': _deviceId,
      };

      await _db.ref('games/$_gameCode/critical_state').set(stateUpdate);
      AppLogger.multiplayer('Critical state synced to RTDB');
    } catch (e) {
      AppLogger.error('Failed to sync critical state', e);
    }
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

  /// Get current game state from Firebase RTDB
  Future<Map<String, dynamic>?> getGameState() async {
    try {
      final snapshot = await _db.ref('games/$_gameCode/state').get();
      if (snapshot.exists) {
        final data = snapshot.value;
        return _convertToStringDynamicMap(data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get game state', e);
      return null;
    }
  }

  /// Listen for game state changes
  Stream<Map<String, dynamic>> watchGameState() {
    return _db.ref('games/$_gameCode/state').onValue.map((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value;
        return _convertToStringDynamicMap(data);
      }
      return <String, dynamic>{};
    });
  }

  /// Request game state sync from other player
  Future<void> requestGameStateSync() async {
    try {
      await sendCommand('request_sync', {
        'requester': _deviceId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      AppLogger.multiplayer('Requested game state sync');
    } catch (e) {
      AppLogger.error('Failed to request game state sync', e);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    AppLogger.info('🔌 Disposing RTDB service...');

    // Send leave command if connected
    if (_initialized) {
      try {
        await sendCommand('leave', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        AppLogger.error('Error sending leave command: $e');
      }
    }

    // Cancel subscriptions
    await _commandSubscription?.cancel();
    await _connectionSubscription?.cancel();

    // Stop syncing
    if (_gameRef != null) {
      await _gameRef!.keepSynced(false);
    }

    // Close stream controller
    await _cmdCtrl.close();

    // Reset state
    _initialized = false;
    _processedCommands.clear();
    _rttSamples.clear();

    AppLogger.info('👋 RTDB service disposed');
  }

  /// Get database reference for direct access (testing)
  DatabaseReference? get gameRef => _gameRef;

  /// Check if we have an active game reference
  bool get hasGameRef => _gameRef != null;
}
