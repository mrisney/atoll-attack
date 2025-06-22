// lib/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_doc.dart';
import '../services/share_service.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';
import '../widgets/draggable_selected_units_panel.dart';
import 'package:flame/game.dart';

/// Main game screen with integrated invite-sharing and join notifications.
class GameScreen extends ConsumerStatefulWidget {
  /// Optional game code for invite join or rejoin.
  final String? gameCode;
  const GameScreen({Key? key, this.gameCode}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  StreamSubscription<GameDoc>? _joinSub;
  bool showPanel = false;
  bool showHUD = true;
  bool showSelectedUnitsPanel = true;
  bool isSettingsMode = true;

  // Invite icon highlight when opponent arrives
  bool _opponentJoined = false;
  String? _joinedPlayerId;
  static const Color goldColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    final code = widget.gameCode;
    if (code != null) {
      _persistGameCode(code);
      ShareService.instance.listenForJoin(code, (GameDoc gameDoc) {
        setState(() {
          _opponentJoined = true;
          _joinedPlayerId =
              gameDoc.players.isNotEmpty ? gameDoc.players.last : null;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _opponentJoined = false;
              _joinedPlayerId = null;
            });
          }
        });
      }).then((sub) => _joinSub = sub);
    }
  }

  Future<void> _persistGameCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGameCode', code);
  }

  @override
  void dispose() {
    _joinSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final gameStats = ref.watch(gameStatsProvider);
    final media = MediaQuery.of(context);
    final code = widget.gameCode;

    // Setup unit-count callback
    if (game.onUnitCountsChanged == null) {
      game.onUnitCountsChanged = () {
        if (mounted) {
          gameNotifier.notifyUnitCountsChanged();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
      };
    }

    return Scaffold(
      body: Stack(
        children: [
          // Game canvas
          GameWidget(game: game),

          // HUD overlay
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
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

          // Settings/controls toggle
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isSettingsMode ? Icons.tune : Icons.sports_esports,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Settings panel
          if (showPanel)
            Positioned(
              bottom: media.padding.bottom + 12,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTabButton('Settings', Icons.tune, true),
                        _buildTabButton(
                            'Controls', Icons.sports_esports, false),
                      ],
                    ),
                  ),
                  Container(
                    constraints:
                        BoxConstraints(maxHeight: media.size.height * 0.4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: isSettingsMode
                        ? IslandSettingsPanel(
                            onClose: () => setState(() => showPanel = false))
                        : GameControlsPanel(
                            onClose: () => setState(() => showPanel = false)),
                  ),
                ],
              ),
            ),

          // Selected units panel
          if (game.selectedUnits.isNotEmpty && showSelectedUnitsPanel)
            DraggableSelectedUnitsPanel(
              unitsInfo: game.getSelectedUnitsInfo(),
              onClose: () {
                game.clearSelection();
                setState(() {});
              },
            ),

          // Victory banner
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
                  border: Border.all(color: goldColor, width: 2),
                ),
                child: const Text(
                  '🎉 VICTORY! 🎉',
                  style: TextStyle(
                    color: goldColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Share icon & join notification
          if (code != null)
            Positioned(
              bottom: media.padding.bottom + 16,
              right: 16,
              child: Column(
                children: [
                  if (_joinedPlayerId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Player ${_joinedPlayerId!.substring(0, 6)} joined',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => ShareService.instance.shareGameInvite(code),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(_opponentJoined ? 0.8 : 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, bool isSettingsTab) {
    final isActive = isSettingsMode == isSettingsTab;
    return GestureDetector(
      onTap: () => setState(() => isSettingsMode = isSettingsTab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
