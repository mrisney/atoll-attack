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

  @override
  Widget build(BuildContext context) {
    final gameNotifier = ref.watch(gameProvider.notifier);
    final game = ref.watch(gameProvider);
    final showPerimeter = ref.watch(showPerimeterProvider);
    final unitCounts = ref.watch(unitCountsProvider);

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    final safePadding = MediaQuery.of(context).padding;

    // Set up the callback to notify when unit counts change
    game.onUnitCountsChanged = () {
      gameNotifier.notifyUnitCountsChanged();
    };

    // Force periodic updates to keep HUD in sync
    ref.listen(gameProvider, (previous, next) {
      // This will trigger rebuilds when game state changes
      if (mounted) {
        setState(() {});
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Game widget takes full screen
          GameWidget(game: game),

          // Game HUD with responsive positioning
          Positioned(
            top: safePadding.top + (isLandscape ? 8 : 12),
            left: isLandscape ? 12 : 16,
            right: isLandscape ? screenSize.width * 0.4 : 16,
            child: GameHUD(
              blueUnits: unitCounts['blueActive'] ?? 0,
              redUnits: unitCounts['redActive'] ?? 0,
              blueHealthPercent: game.blueHealthPercent,
              redHealthPercent: game.redHealthPercent,
              isVisible: showHUD,
              onToggleVisibility: () => setState(() => showHUD = !showHUD),
              selectedUnit: game.selectedUnit?.model,
              blueUnitsRemaining: unitCounts['blueRemaining'] ?? 0,
              redUnitsRemaining: unitCounts['redRemaining'] ?? 0,
              showPerimeter: showPerimeter,
              onPerimeterToggle: (value) {
                ref.read(showPerimeterProvider.notifier).state = value;
              },
            ),
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
                child: Text(
                  'Landscape Mode • Tap units to select • Drag to move',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
