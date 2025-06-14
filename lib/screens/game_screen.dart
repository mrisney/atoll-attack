import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool showSettings = false;
  bool showControls = false;

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);

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
                backgroundColor: Colors.orange,
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
        if (showSettings)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: IslandSettingsPanel(
                onClose: () => setState(() => showSettings = false)),
          ),
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
