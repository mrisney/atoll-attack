// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';
import '../widgets/draggable_selected_units_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool showPanel = false; // Combined settings/controls panel
  bool showHUD = true;
  bool showSelectedUnitsPanel = true;
  bool isSettingsMode = true; // true = settings, false = controls

  static const Color goldColor = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final gameStats = ref.watch(gameStatsProvider);

    final screenSize = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;

    // Set up callback
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
          // Game widget
          GameWidget(game: game),

          // Compact HUD
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

          // Minimized HUD button
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
                  child: const Icon(Icons.info_outline,
                      color: Colors.white, size: 20),
                ),
              ),
            ),

          // Single control button (replaces two FABs)
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

          // Combined panel
          if (showPanel)
            Positioned(
              bottom: safePadding.bottom + 12,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tab selector
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
                  // Panel content
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: screenSize.height * 0.4,
                    ),
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

          // Selected units panel (draggable)
          if (game.selectedUnits.isNotEmpty && showSelectedUnitsPanel)
            DraggableSelectedUnitsPanel(
              unitsInfo: game.getSelectedUnitsInfo(),
              onClose: () {
                game.clearSelection();
                setState(() {});
              },
            ),

          // Victory notification
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
    );
  }

  Widget _buildTabButton(String label, IconData icon, bool isSettings) {
    final isActive = isSettingsMode == isSettings;
    return GestureDetector(
      onTap: () => setState(() => isSettingsMode = isSettings),
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
