import 'dart:async';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _log = Logger();
  final List<int> _rttSamples = [];
  late String _gameCode;
  StreamController<Map<String, dynamic>> _cmdCtrl =
      StreamController.broadcast();

  bool _initialized = false;

  /// true once initialize() completes without error
  bool get isConnected => _initialized;

  /// your last RTT in ms
  int? get lastRtt => _rttSamples.isEmpty ? null : _rttSamples.last;

  /// average RTT
  double get avgRtt => _rttSamples.isEmpty
      ? 0
      : _rttSamples.reduce((a, b) => a + b) / _rttSamples.length;

  Stream<Map<String, dynamic>> get commandStream => _cmdCtrl.stream;

  Future<void> initialize(String gameCode) async {
    _gameCode = gameCode;
    final client = Supabase.instance.client;

    // subscribe to inserts on game_commands for this code
    client.from('game_commands:game_code=eq.$_gameCode').stream(['id']).listen(
        (List<Map<String, dynamic>> records) {
      for (final rec in records) {
        final type = rec['type'] as String? ?? '';
        final payload = rec['payload'] as Map<String, dynamic>? ?? {};

        if (type == 'pong') {
          final pingTs = payload['ping_ts'] as int? ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          final rtt = now - pingTs;
          _rttSamples.add(rtt);
          _log.i('↩️ Pong received, RTT = ${rtt}ms');
        } else if (type == 'ping') {
          // auto‐reply
          sendCommand('pong', {'ping_ts': payload['ping_ts']});
        } else {
          _cmdCtrl.add(rec);
        }
      }
      _initialized = true;
    }, onError: (e, st) {
      _log.e('Realtime subscription failed', e, st);
      _initialized = false;
    });
  }

  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    final client = Supabase.instance.client;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rec = {
      'game_code': _gameCode,
      'type': type,
      'payload': {...payload, if (type == 'ping') 'ping_ts': now},
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await client.from('game_commands').insert(rec).select();
    if (response.error != null) {
      _log.e('❌ sendCommand("$type") failed: ${response.error!.message}');
    } else {
      _log.i('✅ Sent command: $type');
    }
  }

  Future<void> dispose() async {
    await _cmdCtrl.close();
    _initialized = false;
  }
}
