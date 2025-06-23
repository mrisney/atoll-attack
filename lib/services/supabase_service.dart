import 'dart:async';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _log = Logger();
  final List<int> _rttSamples = [];
  late String _gameCode;
  String? _deviceId;
  StreamController<Map<String, dynamic>> _cmdCtrl =
      StreamController.broadcast();

  bool _initialized = false;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  final Set<int> _processedIds = {}; // Track processed message IDs

  /// true once initialize() completes without error
  bool get isConnected => _initialized;

  /// your last RTT in ms
  int? get lastRtt => _rttSamples.isEmpty ? null : _rttSamples.last;

  /// average RTT
  double get avgRtt => _rttSamples.isEmpty
      ? 0
      : _rttSamples.reduce((a, b) => a + b) / _rttSamples.length;

  /// get latest RTT samples (for display)
  List<int> get rttSamples => List.unmodifiable(_rttSamples);

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

  Future<void> initialize(String gameCode) async {
    _gameCode = gameCode;
    final client = Supabase.instance.client;

    // Ensure we have a device ID
    await _getDeviceId();
    _log.i('🔧 Initializing with device ID: ${_deviceId?.substring(0, 8)}...');

    // Clear processed IDs when reinitializing
    _processedIds.clear();

    try {
      // First, test if we can read from the table
      final testQuery = await client
          .from('game_commands')
          .select()
          .eq('game_code', _gameCode)
          .limit(1);

      _log.i('✅ Table access confirmed, setting up realtime subscription...');

      // Use the stream API similar to the chat example
      _subscription = client
          .from('game_commands')
          .stream(primaryKey: ['id'])
          .eq('game_code', _gameCode)
          .order('created_at', ascending: true)
          .listen(
            (List<Map<String, dynamic>> data) {
              // Process only new commands
              for (final rec in data) {
                final id = rec['id'] as int?;
                if (id == null || _processedIds.contains(id)) {
                  continue; // Skip if already processed
                }
                _processedIds.add(id);

                final type = rec['type'] as String? ?? '';
                final cmdPayload =
                    rec['payload'] as Map<String, dynamic>? ?? {};
                final senderId = rec['sender_id'] as String? ?? 'unknown';

                // Don't process our own messages (except for ping/pong)
                if (type != 'ping' && type != 'pong' && senderId == _deviceId) {
                  continue; // Skip our own messages
                }

                if (type == 'pong') {
                  final pingTs = cmdPayload['ping_ts'] as int? ?? 0;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final rtt = now - pingTs;
                  _rttSamples.add(rtt);
                  if (_rttSamples.length > 10)
                    _rttSamples.removeAt(0); // Keep last 10 samples
                  _log.i('↩️ Pong received, RTT = ${rtt}ms');
                } else if (type == 'ping') {
                  // auto‐reply only if it's not our own ping
                  if (senderId != _deviceId) {
                    sendCommand('pong', {'ping_ts': cmdPayload['ping_ts']});
                  }
                } else {
                  // Forward other commands to the stream
                  _cmdCtrl.add(rec);
                }
              }

              // Set initialized after first batch
              if (!_initialized) {
                _initialized = true;
                _log.i('✅ Realtime subscription active for game $_gameCode');
              }

              // Clean up old IDs to prevent memory growth
              if (_processedIds.length > 1000) {
                final sortedIds = _processedIds.toList()..sort();
                final toKeep = sortedIds.sublist(sortedIds.length - 500);
                _processedIds.clear();
                _processedIds.addAll(toKeep);
              }
            },
            onError: (error) {
              _log.e('❌ Realtime subscription failed: $error');
              _initialized = false;

              // Try to reconnect after a delay
              Future.delayed(const Duration(seconds: 5), () {
                if (!_initialized && _gameCode == gameCode) {
                  _log.i('🔄 Attempting to reconnect...');
                  initialize(gameCode);
                }
              });
            },
            cancelOnError: false, // Don't cancel subscription on error
          );
    } catch (e) {
      _log.e('❌ Failed to initialize: $e');
      _initialized = false;
    }
  }

  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    final client = Supabase.instance.client;
    final now = DateTime.now().millisecondsSinceEpoch;
    final deviceId = await _getDeviceId();

    final rec = {
      'game_code': _gameCode,
      'sender_id': deviceId, // Use device ID instead of user ID
      'type': type,
      'payload': {...payload, if (type == 'ping') 'ping_ts': now},
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await client.from('game_commands').insert(rec);
      _log.i(
          '✅ Sent command: $type from device: ${deviceId.substring(0, 8)}...');
    } catch (e) {
      _log.e('❌ sendCommand("$type") failed: $e');
    }
  }

  // Convenience method for sending ping
  Future<void> sendPing() async {
    await sendCommand('ping', {});
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _cmdCtrl.close();
    _initialized = false;
    _processedIds.clear();
  }
}
