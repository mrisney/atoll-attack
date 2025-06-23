// lib/services/firebase_rtdb_service.dart
import 'dart:async';
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
  final _db = FirebaseDatabase.instance;

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
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
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
      // Set up game reference
      _gameRef = _db.ref('games/$_gameCode');

      // Enable offline persistence
      await _db.setPersistenceEnabled(true);
      await _gameRef!.keepSynced(true);

      // Monitor connection state
      _connectionSubscription = _db.ref('.info/connected').onValue.listen(
        (event) {
          final connected = event.snapshot.value as bool? ?? false;
          _log.i(
              '🔌 RTDB Connection: ${connected ? "Connected" : "Disconnected"}');

          if (connected && !_initialized) {
            _initialized = true;
            // Send join command when connected
            sendCommand('join', {
              'device_id': _deviceId,
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        },
      );

      // Listen for new commands
      _commandSubscription = _gameRef!
          .child('commands')
          .orderByChild('timestamp')
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

      // Convert to Map<String, dynamic>
      final command = <String, dynamic>{};
      data.forEach((key, value) {
        if (key is String) {
          command[key] = value;
        }
      });

      final type = command['type'] as String? ?? '';
      final senderId = command['sender_id'] as String? ?? 'unknown';
      final payload = command['payload'] as Map<Object?, Object?>? ?? {};

      // Convert payload to proper type
      final typedPayload = <String, dynamic>{};
      payload.forEach((key, value) {
        if (key is String) {
          typedPayload[key] = value;
        }
      });

      // Handle ping/pong for latency measurement
      if (type == 'ping' && senderId != _deviceId) {
        // Respond to ping
        final pingTs = typedPayload['ping_ts'] as int? ?? 0;
        sendCommand('pong', {
          'ping_ts': pingTs,
          'pong_ts': DateTime.now().millisecondsSinceEpoch,
        });
      } else if (type == 'pong' && senderId != _deviceId) {
        // Calculate RTT
        final pingTs = typedPayload['ping_ts'] as int? ?? 0;
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

  /// Send a command
  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    if (!_initialized || _gameRef == null) {
      _log.w('⚠️ Cannot send command - not initialized');
      return;
    }

    final deviceId = await _getDeviceId();

    try {
      final command = {
        'type': type,
        'payload': payload,
        'sender_id': deviceId,
        'timestamp': ServerValue.timestamp,
      };

      // Add timestamp to payload for ping
      if (type == 'ping') {
        command['payload'] = {
          ...payload,
          'ping_ts': DateTime.now().millisecondsSinceEpoch,
        };
      }

      await _gameRef!.child('commands').push().set(command);

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
