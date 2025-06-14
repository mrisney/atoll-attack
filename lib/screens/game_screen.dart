import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../providers/game_provider.dart';
import '../widgets/island_settings_panel.dart';
import '../widgets/game_controls_panel.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);

    return Stack(
      children: [
        GameWidget(game: game),
        Positioned(
          right: 16,
          bottom: 16,
          child: IslandSettingsPanel(),
        ),
        // You can add GameControlsPanel similarly
      ],
    );
  }
}
