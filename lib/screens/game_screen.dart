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

    // Force periodic updates to keep HUD in sync
    ref.listen(gameProvider, (previous, next) {
      // This will trigger rebuilds when game state changes
      if (mounted) {
        setState(() {});
      }
    });

    return Stack(
      children: [
        GameWidget(game: game),

        // Game HUD with reactive unit counts and perimeter toggle
        GameHUD(
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

        // Control buttons
        Positioned(
          top: 30,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: "islandSettingsBtn",
                mini: true,
                backgroundColor: Colors.blueGrey.withOpacity(0.8),
                child: const Icon(Icons.settings),
                onPressed: () {
                  setState(() {
                    showSettings = !showSettings;
                    if (showSettings) showControls = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "gameControlsBtn",
                mini: true,
                backgroundColor: Colors.orange.withOpacity(0.8),
                child: const Icon(Icons.sports_esports),
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

        // Settings panel (more transparent)
        if (showSettings)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
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

        // Controls panel with individual unit spawning
        if (showControls)
          Positioned(
            right: 12,
            bottom: 24,
            child: GameControlsPanel(
              onClose: () => setState(() => showControls = false),
            ),
          ),
      ],
    );
  }
}
