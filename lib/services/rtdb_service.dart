// lib/services/rtdb_service.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class FirebaseRTDBService {
  FirebaseRTDBService._();
  static final FirebaseRTDBService instance = FirebaseRTDBService._();

  final _log = Logger();
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
      _log.i('🆆 Generated new device ID: ${deviceId.substring(0, 12)}...');
    }

    _deviceId = deviceId;
    return deviceId;
  }

  /// Initialize the RTDB service for a game
  Future<void> initialize(String gameCode) async {
    _gameCode = gameCode;

    // Ensure we have a device ID
    await _getDeviceId();
    _log.i(
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
          _log.i(
              '🔌 RTDB Connection: ${connected ? "Connected" : "Disconnected"} (initialized: $_initialized)');

          if (connected) {
            if (!_initialized) {
              _initialized = true;
              _log.i('🎉 First connection established - sending join command');
              // Send join command when connected
              sendCommand('join', {
                'device_id': _deviceId,
                'timestamp': DateTime.now().toIso8601String(),
              });
            } else {
              _log.i('🔄 Reconnected to RTDB');
            }
          } else {
            if (_initialized) {
              _log.w('⚠️ Lost RTDB connection');
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
          _log.e('❌ Command subscription error: $error');
        },
      );

      _log.i('✅ RTDB initialized for game $_gameCode');
    } catch (e) {
      _log.e('❌ Failed to initialize RTDB: $e');
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

        _log.i(
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

        _log.i(
            '📥 Command received: $type from ${senderId.substring(0, 8)}...');
      }
    } catch (e) {
      _log.e('❌ Error handling command: $e');
    }
  }

  /// Send a command (optimized for low latency)
  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    if (!_initialized || _gameRef == null) {
      _log.w('⚠️ Cannot send command - not initialized');
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

      _log.i('📤 Sent command: $type');
    } catch (e) {
      _log.e('❌ Failed to send command "$type": $e');
    }
  }

  /// Send a ping to measure latency
  Future<void> sendPing() async {
    await sendCommand('ping', {});
  }

  /// Clean up resources
  Future<void> dispose() async {
    _log.i('🔌 Disposing RTDB service...');

    // Send leave command if connected
    if (_initialized) {
      try {
        await sendCommand('leave', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        _log.e('Error sending leave command: $e');
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

    _log.i('👋 RTDB service disposed');
  }

  /// Get database reference for direct access (testing)
  DatabaseReference? get gameRef => _gameRef;

  /// Check if we have an active game reference
  bool get hasGameRef => _gameRef != null;
}
