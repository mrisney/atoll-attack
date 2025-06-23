// lib/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../models/game_doc.dart';
import '../services/share_service.dart';
import '../services/supabase_service.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';
import '../widgets/draggable_selected_units_panel.dart';
import 'package:flame/game.dart';

final logger = Logger();

class GameScreen extends ConsumerStatefulWidget {
  final String? gameCode;
  const GameScreen({Key? key, this.gameCode}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  StreamSubscription<GameDoc>? _joinSub;
  StreamSubscription<Map<String, dynamic>>? _cmdSub;
  bool showPanel = false,
      showHUD = true,
      showSelectedUnitsPanel = true,
      isSettingsMode = true;
  bool _opponentJoined = false;
  String? _joinedPlayerId;
  int _latency = 0;
  Timer? _latencyTimer;
  bool _isConnected = false;
  static const Color goldColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    final code = widget.gameCode;
    if (code != null) {
      _persistGameCode(code);
      _initializeSupabase(code);
      // keep existing share listener
      ShareService.instance.listenForJoin(code, (GameDoc doc) {
        setState(() {
          _opponentJoined = true;
          _joinedPlayerId = doc.players.isNotEmpty ? doc.players.last : null;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted)
            setState(() {
              _opponentJoined = false;
              _joinedPlayerId = null;
            });
        });
      }).then((sub) => _joinSub = sub);
    }
    // update latency display once/sec
    _latencyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted)
        setState(
            () => _latency = SupabaseService.instance.averageLatency.round());
    });
  }

  Future<void> _initializeSupabase(String code) async {
    try {
      await SupabaseService.instance.initialize(code);
      setState(() => _isConnected = true);
      logger.i('Supabase connected to game $code');
      // show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Realtime connected'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // listen for incoming commands
      _cmdSub = SupabaseService.instance.commandStream.listen((cmd) {
        logger.i('Command received: ${cmd['type']}');
        // handle your game commands...
      });
    } catch (e) {
      logger.e('Init error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _persistGameCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGameCode', code);
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    _cmdSub?.cancel();
    SupabaseService.instance.dispose();
    _joinSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final stats = ref.watch(gameStatsProvider);
    final media = MediaQuery.of(context);

    // ensure onUnitCountsChanged is set...
    if (game.onUnitCountsChanged == null) {
      game.onUnitCountsChanged = () {
        gameNotifier.notifyUnitCountsChanged();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      };
    }

    return Scaffold(
      body: Stack(children: [
        GameWidget(game: game),
        if (showHUD)
          Positioned(
            top: media.padding.top + 8,
            left: 16,
            child: GameHUD(
              blueUnits: stats['blueUnits'] ?? 0,
              redUnits: stats['redUnits'] ?? 0,
              blueHealthPercent: stats['blueHealth'] ?? 0.0,
              redHealthPercent: stats['redHealth'] ?? 0.0,
              isVisible: showHUD,
              onToggleVisibility: () => setState(() => showHUD = !showHUD),
              blueUnitsRemaining: stats['blueRemaining'] ?? 0,
              redUnitsRemaining: stats['redRemaining'] ?? 0,
            ),
          ),
        if (!showHUD)
          Positioned(
            top: media.padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => setState(() => showHUD = true),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.info_outline,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        if (widget.gameCode != null)
          Positioned(
            top: media.padding.top + 60,
            left: 16,
            child: _buildStatus(),
          ),
        // settings toggle & panel, selected units, victory, share icon, ping button...
        // identical to before, except:
        // Ping button calls SupabaseService.instance.sendPing()
        // Test commands call SupabaseService.instance.sendCommand(...)
        // Remove all WebRTCService.instance calls and replace with SupabaseService.instance
      ]),
    );
  }

  Widget _buildStatus() {
    final connColor = _isConnected ? Colors.green : Colors.red;
    final latColor = _latency < 50
        ? Colors.green
        : (_latency < 100 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_isConnected ? Icons.cloud : Icons.cloud_off,
            color: connColor, size: 16),
        const SizedBox(width: 4),
        Text('Realtime',
            style: TextStyle(
                color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: latColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: latColor)),
          child: Text(_latency > 0 ? '${_latency}ms' : '--',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        )
      ]),
    );
  }
}
