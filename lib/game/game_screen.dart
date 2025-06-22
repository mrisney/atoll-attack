// lib/screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../services/room_service.dart' as room_service;
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';
import '../widgets/draggable_selected_units_panel.dart';
import 'package:flame/game.dart';
import 'join_screen.dart' show JoinScreen;

/// Main game screen, supports both room creation and subscription.
class GameScreen extends ConsumerStatefulWidget {
  /// Optional game code for join or rejoin flows.
  final String? gameCode;
  const GameScreen({Key? key, this.gameCode}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  StreamSubscription<room_service.GameDoc>? _roomSub;
  bool showPanel = false;
  bool showHUD = true;
  bool showSelectedUnitsPanel = true;
  bool isSettingsMode = true;
  static const Color goldColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    if (widget.gameCode != null) {
      _persistGameCode(widget.gameCode!);
      _subscribeToRoom(widget.gameCode!);
    }
  }

  /// Save last game code locally for rejoin support.
  Future<void> _persistGameCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGameCode', code);
  }

  /// Listen to Firestore room document for state changes.
  void _subscribeToRoom(String code) {
    _roomSub = room_service.RoomService.instance.watchRoom(code).listen(
      (game) {
        if (game.state == 'active') {
          // Both players joined; proceed with real-time sync / gameplay
        } else if (game.state == 'expired') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game expired')),
          );
        }
      },
      onError: (err) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $err')));
      },
    );
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final gameStats = ref.watch(gameStatsProvider);
    final screenSize = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;

    // Setup game callbacks
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

    // Determine share link availability
    final code = widget.gameCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Atoll Attack'),
        actions: [
          if (code != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                final link = 'https://link.atoll-attack.com/join?code=$code';
                Share.share(
                  '🏝️ Join me in Atoll Attack! Tap: $link',
                  subject: 'Atoll Attack Invite',
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Flame game widget
          GameWidget(game: game),

          // HUD overlay
          if (showHUD)
            Positioned(
              top: safePadding.top + 8,
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
              top: safePadding.top + 8,
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

          // Panel toggle
          Positioned(
            top: safePadding.top + 8,
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

          // Settings/Controls panel
          if (showPanel)
            Positioned(
              bottom: safePadding.bottom + 12,
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
                        BoxConstraints(maxHeight: screenSize.height * 0.4),
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
                            onClose: () => setState(() => showPanel = false),
                          )
                        : GameControlsPanel(
                            onClose: () => setState(() => showPanel = false),
                          ),
                  ),
                ],
              ),
            ),

          // Selected units
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
              top: screenSize.height * 0.3,
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
        ],
      ),
      floatingActionButton: code == null
          ? FloatingActionButton(
              onPressed: () async {
                final newCode = await room_service.RoomService.instance
                    .createRoom(settings: {});
                await _persistGameCode(newCode);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JoinScreen(inviteCode: newCode),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
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
