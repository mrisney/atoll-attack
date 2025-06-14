import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';
import '../providers/show_perimeter_provider.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final showSettings = useState(false);
    final showControls = useState(false);

    return Stack(
      children: [
        GameWidget(game: game),
        Positioned(
          top: 30,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: "islandSettingsBtn",
                mini: true,
                backgroundColor: Colors.blueGrey,
                child: const Icon(Icons.settings),
                onPressed: () {
                  showSettings.value = !showSettings.value;
                  if (showSettings.value) showControls.value = false;
                },
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "gameControlsBtn",
                mini: true,
                backgroundColor: Colors.orange,
                child: const Icon(Icons.sports_esports),
                onPressed: () {
                  showControls.value = !showControls.value;
                  if (showControls.value) showSettings.value = false;
                },
              ),
            ],
          ),
        ),
        if (showSettings.value)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child:
                IslandSettingsPanel(onClose: () => showSettings.value = false),
          ),
        if (showControls.value)
          Positioned(
            right: 12,
            bottom: 24,
            child: GameControlsPanel(
              onClose: () => showControls.value = false,
            ),
          ),
      ],
    );
  }
}
