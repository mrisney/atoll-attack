import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../providers/game_provider.dart';
import '../providers/show_perimeter_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../widgets/game_hud.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool showSettings = false;
  bool showControls = false;
  bool showHUD = true;

  // Define a custom gold color since Colors.gold doesn't exist
  static const Color goldColor = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final showPerimeter = ref.watch(showPerimeterProvider);

    // Watch the reactive providers for unit counts and game stats
    final unitCounts = ref.watch(unitCountsProvider);
    final gameStats = ref.watch(gameStatsProvider);

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final safePadding = MediaQuery.of(context).padding;

    // Set up the callback to notify when unit counts change
    game.onUnitCountsChanged = () {
      if (mounted) {
        gameNotifier.notifyUnitCountsChanged();
        // Also force a rebuild of this widget
        setState(() {});
      }
    };

    return Scaffold(
      body: Stack(
        children: [
          // Game widget takes full screen
          GameWidget(game: game),

          // Game HUD with reactive data
          Positioned(
            top: safePadding.top + (isLandscape ? 8 : 12),
            left: isLandscape ? 12 : 16,
            right: isLandscape ? screenSize.width * 0.4 : 16,
            child: _buildGameHUD(gameStats, showPerimeter, game),
          ),

          // Control buttons - responsive positioning
          Positioned(
            top: safePadding.top + (isLandscape ? 8 : 16),
            right: isLandscape ? 12 : 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "islandSettingsBtn",
                  mini: !isLandscape,
                  backgroundColor: Colors.blueGrey.withOpacity(0.8),
                  child: Icon(
                    Icons.settings,
                    size: isLandscape ? 24 : 20,
                  ),
                  onPressed: () {
                    setState(() {
                      showSettings = !showSettings;
                      if (showSettings) showControls = false;
                    });
                  },
                ),
                SizedBox(height: isLandscape ? 16 : 12),
                FloatingActionButton(
                  heroTag: "gameControlsBtn",
                  mini: !isLandscape,
                  backgroundColor: Colors.orange.withOpacity(0.8),
                  child: Icon(
                    Icons.sports_esports,
                    size: isLandscape ? 24 : 20,
                  ),
                  onPressed: () {
                    setState(() {
                      showControls = !showControls;
                      if (showControls) showSettings = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Settings panel - responsive positioning and sizing
          if (showSettings)
            Positioned(
              left: isLandscape ? 12 : 12,
              right: isLandscape ? 12 : 12,
              bottom: isLandscape ? 12 : safePadding.bottom + 12,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: isLandscape
                      ? screenSize.height * 0.7
                      : screenSize.height * 0.4,
                  maxWidth: isLandscape ? 600 : double.infinity,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: IslandSettingsPanel(
                    onClose: () => setState(() => showSettings = false),
                  ),
                ),
              ),
            ),

          // Controls panel - responsive positioning
          if (showControls)
            Positioned(
              right: isLandscape ? 12 : 12,
              bottom: isLandscape ? 12 : safePadding.bottom + 12,
              left: isLandscape ? screenSize.width * 0.3 : null,
              child: GameControlsPanel(
                onClose: () => setState(() => showControls = false),
              ),
            ),

          // Debug info in landscape mode (optional)
          if (isLandscape && showHUD)
            Positioned(
              bottom: safePadding.bottom + 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildDebugInfo(gameStats),
              ),
            ),

          // Victory notification
          _buildVictoryNotification(gameStats, screenSize),
        ],
      ),
    );
  }

  Widget _buildGameHUD(dynamic gameStats, bool showPerimeter, dynamic game) {
    // Check if gameStats is AsyncValue or Map
    if (gameStats is AsyncValue) {
      return gameStats.when(
        data: (stats) => GameHUD(
          blueUnits: stats['blueUnits'] ?? 0,
          redUnits: stats['redUnits'] ?? 0,
          blueHealthPercent: stats['blueHealth'] ?? 0.0,
          redHealthPercent: stats['redHealth'] ?? 0.0,
          isVisible: showHUD,
          onToggleVisibility: () => setState(() => showHUD = !showHUD),
          selectedUnit: game.selectedUnit?.model,
          blueUnitsRemaining: stats['blueRemaining'] ?? 0,
          redUnitsRemaining: stats['redRemaining'] ?? 0,
          showPerimeter: showPerimeter,
          onPerimeterToggle: (value) {
            ref.read(showPerimeterProvider.notifier).state = value;
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    } else {
      // Handle as Map<String, dynamic>
      final stats = gameStats as Map<String, dynamic>;
      return GameHUD(
        blueUnits: stats['blueUnits'] ?? 0,
        redUnits: stats['redUnits'] ?? 0,
        blueHealthPercent: stats['blueHealth'] ?? 0.0,
        redHealthPercent: stats['redHealth'] ?? 0.0,
        isVisible: showHUD,
        onToggleVisibility: () => setState(() => showHUD = !showHUD),
        selectedUnit: game.selectedUnit?.model,
        blueUnitsRemaining: stats['blueRemaining'] ?? 0,
        redUnitsRemaining: stats['redRemaining'] ?? 0,
        showPerimeter: showPerimeter,
        onPerimeterToggle: (value) {
          ref.read(showPerimeterProvider.notifier).state = value;
        },
      );
    }
  }

  Widget _buildDebugInfo(dynamic gameStats) {
    if (gameStats is AsyncValue) {
      return gameStats.when(
        data: (stats) => Text(
          'Blue: ${stats['blueUnits']} | Red: ${stats['redUnits']} | Selected: ${stats['selectedUnitCount']}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 10,
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    } else {
      final stats = gameStats as Map<String, dynamic>;
      return Text(
        'Blue: ${stats['blueUnits']} | Red: ${stats['redUnits']} | Selected: ${stats['selectedUnitCount']}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 10,
        ),
      );
    }
  }

  Widget _buildVictoryNotification(dynamic gameStats, Size screenSize) {
    bool isVictoryAchieved = false;

    if (gameStats is AsyncValue) {
      return gameStats.when(
        data: (stats) {
          isVictoryAchieved = stats['isVictoryAchieved'] == true;
          return _victoryWidget(isVictoryAchieved, screenSize);
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    } else {
      final stats = gameStats as Map<String, dynamic>;
      isVictoryAchieved = stats['isVictoryAchieved'] == true;
      return _victoryWidget(isVictoryAchieved, screenSize);
    }
  }

  Widget _victoryWidget(bool isVictoryAchieved, Size screenSize) {
    if (!isVictoryAchieved) return const SizedBox.shrink();

    return Positioned(
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
    );
  }
}
