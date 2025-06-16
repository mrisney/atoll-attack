import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/island_settings.dart';
import '../constants/game_config.dart';
import '../game/island_game.dart';
import 'show_perimeter_provider.dart';
import 'island_settings_provider.dart';

// Enhanced game notifier with better state management
class GameNotifier extends StateNotifier<IslandGame> {
  GameNotifier(IslandGame game) : super(game) {
    // Set up the callback to trigger updates when unit counts change
    state.onUnitCountsChanged = () {
      // Force state update by creating a new reference
      if (mounted) {
        state = state;
      }
    };
  }

  void forceUpdate() {
    // Trigger a rebuild by creating a new state reference
    if (mounted) {
      state = state;
    }
  }

  // Method to manually trigger updates when unit counts change
  void notifyUnitCountsChanged() {
    if (mounted) {
      forceUpdate();
    }
  }

  // Manual refresh method for forcing updates
  void refreshGameState() {
    if (mounted) {
      state = state;
    }
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

// State provider that tracks unit counts and forces reactivity
final unitCountsProvider = StateProvider<Map<String, int>>((ref) {
  final game = ref.watch(gameProvider);

  // Create a new map each time to ensure reactivity
  return {
    'blueActive': game.blueUnitCount,
    'redActive': game.redUnitCount,
    'blueRemaining': game.blueUnitsRemaining,
    'redRemaining': game.redUnitsRemaining,
    'blueSpawned': game.blueUnitsSpawned,
    'redSpawned': game.redUnitsSpawned,
    'blueCaptainsRemaining': game.blueCaptainsRemaining,
    'blueArchersRemaining': game.blueArchersRemaining,
    'blueSwordsmenRemaining': game.blueSwordsmenRemaining,
    'redCaptainsRemaining': game.redCaptainsRemaining,
    'redArchersRemaining': game.redArchersRemaining,
    'redSwordsmenRemaining': game.redSwordsmenRemaining,
    // Add timestamp to force refresh
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
});

// Individual reactive providers for more granular updates
final blueUnitCountsProvider = Provider<Map<String, int>>((ref) {
  final game = ref.watch(gameProvider);
  return {
    'captains': game.blueCaptainsRemaining,
    'archers': game.blueArchersRemaining,
    'swordsmen': game.blueSwordsmenRemaining,
    'total': game.blueUnitsRemaining,
    'active': game.blueUnitCount,
  };
});

final redUnitCountsProvider = Provider<Map<String, int>>((ref) {
  final game = ref.watch(gameProvider);
  return {
    'captains': game.redCaptainsRemaining,
    'archers': game.redArchersRemaining,
    'swordsmen': game.redSwordsmenRemaining,
    'total': game.redUnitsRemaining,
    'active': game.redUnitCount,
  };
});

// Health tracking provider
final teamHealthProvider = Provider<Map<String, double>>((ref) {
  final game = ref.watch(gameProvider);
  return {
    'blueHealth': game.blueHealthPercent,
    'redHealth': game.redHealthPercent,
  };
});

// Game state refresh provider - call this to force updates
final gameStateRefreshProvider = Provider<void>((ref) {
  // This provider exists to trigger manual refreshes
  return;
});

// Provider that auto-refreshes every frame (for real-time updates)
final gameFrameProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(milliseconds: 100), (i) => i);
});

// Combined reactive game stats provider
final gameStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final game = ref.watch(gameProvider);
  // Watch the frame provider to get updates every 100ms
  ref.watch(gameFrameProvider);

  return {
    'blueUnits': game.blueUnitCount,
    'redUnits': game.redUnitCount,
    'blueHealth': game.blueHealthPercent,
    'redHealth': game.redHealthPercent,
    'blueRemaining': game.blueUnitsRemaining,
    'redRemaining': game.redUnitsRemaining,
    'selectedUnitCount': game.selectedUnits.length,
    'isVictoryAchieved': game.isVictoryAchieved(),
  };
});
