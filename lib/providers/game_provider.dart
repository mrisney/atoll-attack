import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/island_settings.dart';
import '../config.dart';
import '../game/island_game.dart';
import 'show_perimeter_provider.dart';
import 'island_settings_provider.dart';

// Create a notifier that can trigger updates when game state changes
class GameNotifier extends StateNotifier<IslandGame> {
  GameNotifier(IslandGame game) : super(game);

  void forceUpdate() {
    // Trigger a rebuild by creating a new state reference
    state = state;
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, IslandGame>((ref) {
  final settings = ref.watch(islandSettingsProvider);
  final showPerimeter = ref.watch(showPerimeterProvider);

  final game = IslandGame(
    amplitude: settings.amplitude,
    wavelength: settings.wavelength,
    bias: settings.bias,
    seed: settings.seed,
    islandRadius: settings.islandRadius,
    gameSize: kDefaultGameSize,
    showPerimeter: showPerimeter,
  );

  return GameNotifier(game);
});

// Provider that watches for unit count changes
final unitCountsProvider = Provider<Map<String, int>>((ref) {
  final game = ref.watch(gameProvider);

  // This will automatically update when the game state changes
  return {
    'blueActive': game.blueUnitCount,
    'redActive': game.redUnitCount,
    'blueRemaining': game.blueUnitsRemaining,
    'redRemaining': game.redUnitsRemaining,
    'blueSpawned': game.blueUnitsSpawned,
    'redSpawned': game.redUnitsSpawned,
  };
});
