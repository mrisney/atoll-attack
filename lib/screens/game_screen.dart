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

final _log = Logger();

class GameScreen extends ConsumerStatefulWidget {
  final String? gameCode;
  const GameScreen({Key? key, this.gameCode}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  StreamSubscription<GameDoc>? _joinSub;
  StreamSubscription<Map<String, dynamic>>? _cmdSub;
  Timer? _rttTimer;

  bool showPanel = false;
  bool showHUD = true;
  bool showSelectedUnitsPanel = true;
  bool isSettingsMode = true;

  bool _opponentJoined = false;
  String? _joinedPlayerId;

  @override
  void initState() {
    super.initState();
    final code = widget.gameCode;
    if (code != null) {
      _persistGameCode(code);
      _initializeSupabaseComm(code);

      // still use Firestore for invite-join notifications
      ShareService.instance.listenForJoin(code, (GameDoc doc) {
        setState(() {
          _opponentJoined = true;
          _joinedPlayerId = doc.players.isNotEmpty ? doc.players.last : null;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() {
            _opponentJoined = false;
            _joinedPlayerId = null;
          });
        });
      }).then((sub) => _joinSub = sub);
    }

    // refresh RTT display every second
    _rttTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeSupabaseComm(String code) async {
    try {
      final supa = SupabaseService.instance;
      await supa.initialize(code);

      _showStatus('Supabase Connected!', Colors.green);

      _cmdSub = supa.commandStream.listen((rec) {
        final t = rec['type'] ?? 'unknown';
        final p = rec['payload'] ?? {};
        _log.i('Cmd recv: $t → $p');

        // Show snackbar for messages
        if (t == 'message' || t == 'test') {
          final msg = p['message'] ?? p['msg'] ?? 'Unknown message';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.message, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(msg)),
                  ],
                ),
                backgroundColor: Colors.cyan.shade700,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      });
    } catch (e) {
      _log.e('Supabase init failed: $e');
      _showStatus('Supabase Failed', Colors.red);
    }
  }

  void _showStatus(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: c,
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _persistGameCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGameCode', code);
  }

  @override
  void dispose() {
    _rttTimer?.cancel();
    _cmdSub?.cancel();
    SupabaseService.instance.dispose();
    _joinSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.gameCode;
    final game = ref.watch(gameProvider);
    final gameStats = ref.watch(gameStatsProvider);
    final media = MediaQuery.of(context);

    // unit-counts callback
    if (game.onUnitCountsChanged == null) {
      game.onUnitCountsChanged = () {
        ref.read(gameProvider.notifier).notifyUnitCountsChanged();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => mounted ? setState(() {}) : null);
      };
    }

    // supabase status
    final supa = SupabaseService.instance;
    final conn = supa.isConnected;
    final last = supa.lastRtt;
    final avg = supa.avgRtt;

    return Scaffold(
      body: Stack(children: [
        GameWidget(game: game),

        if (showHUD)
          Positioned(
            top: media.padding.top + 8,
            left: 16,
            child: GameHUD(
              blueUnits: gameStats['blueUnits'] ?? 0,
              redUnits: gameStats['redUnits'] ?? 0,
              blueHealthPercent: gameStats['blueHealth'] ?? 0.0,
              redHealthPercent: gameStats['redHealth'] ?? 0.0,
              isVisible: showHUD,
              onToggleVisibility: () => setState(() => showHUD = !showHUD),
              blueUnitsRemaining: gameStats['blueRemaining'] ?? 0,
              redUnitsRemaining: gameStats['redRemaining'] ?? 0,
            ),
          ),

        if (code != null)
          Positioned(
            top: media.padding.top + 60,
            left: 16,
            child: _buildSupabaseStatus(conn, last, avg),
          ),

        // settings / controls toggle (unchanged)
        Positioned(
          top: media.padding.top + 8,
          right: 16,
          child: GestureDetector(
            onTap: () => setState(() => showPanel = !showPanel),
            onLongPress: () => setState(() {
              showPanel = true;
              isSettingsMode = !isSettingsMode;
            }),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: showPanel
                    ? (isSettingsMode ? Colors.blueGrey : Colors.orange)
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: Icon(
                isSettingsMode ? Icons.tune : Icons.sports_esports,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        if (showPanel)
          Positioned(
            bottom: media.padding.bottom + 12,
            left: 12,
            right: 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _tab('Settings', Icons.tune, true),
                  _tab('Controls', Icons.sports_esports, false),
                ]),
              ),
              Container(
                constraints: BoxConstraints(maxHeight: media.size.height * 0.4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: isSettingsMode
                    ? IslandSettingsPanel(
                        onClose: () => setState(() => showPanel = false))
                    : GameControlsPanel(
                        onClose: () => setState(() => showPanel = false)),
              ),
            ]),
          ),

        if (game.selectedUnits.isNotEmpty && showSelectedUnitsPanel)
          DraggableSelectedUnitsPanel(
            unitsInfo: game.getSelectedUnitsInfo(),
            onClose: () {
              game.clearSelection();
              setState(() {});
            },
          ),

        if (gameStats['isVictoryAchieved'] == true)
          Positioned(
            top: media.size.height * 0.3,
            left: 50,
            right: 50,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.yellow.shade700, width: 2),
              ),
              child: const Text(
                '🎉 VICTORY! 🎉',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

        if (code != null)
          Positioned(
            bottom: media.padding.bottom + 16,
            right: 16,
            child: Column(children: [
              if (_joinedPlayerId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Player ${_joinedPlayerId!.substring(0, 6)} joined',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              GestureDetector(
                onTap: () => ShareService.instance.shareGameInvite(code),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(_opponentJoined ? 0.8 : 0.4),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.share, color: Colors.black87, size: 20),
                ),
              ),
            ]),
          ),

        if (code != null && conn)
          Positioned(
            bottom: media.padding.bottom + 70,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    SupabaseService.instance
                        .sendCommand('test', {'msg': 'Quick test!'});
                  },
                  backgroundColor: Colors.purple,
                  child: const Icon(Icons.send, size: 16),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: () {
                    SupabaseService.instance.sendPing();
                  },
                  backgroundColor: Colors.cyan,
                  child: const Icon(Icons.network_ping, size: 16),
                ),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _buildSupabaseStatus(bool conn, int? last, double avg) {
    final color = conn ? Colors.green : Colors.red;
    final rttColor = (last ?? 999) < 100 ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud, color: color, size: 16),
        const SizedBox(width: 4),
        Text('Supabase',
            style: TextStyle(
                color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: rttColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: rttColor, width: 1),
          ),
          child: Text(
            last != null ? '${last}ms' : '--',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  GestureDetector _tab(String label, IconData icon, bool settings) =>
      GestureDetector(
        onTap: () => setState(() => isSettingsMode = settings),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSettingsMode == settings
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isSettingsMode == settings
                        ? FontWeight.bold
                        : FontWeight.normal)),
          ]),
        ),
      );
}
