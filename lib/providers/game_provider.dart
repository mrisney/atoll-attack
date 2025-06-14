import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/island_settings.dart';
import '../config.dart';
import '../game/island_game.dart';
import 'show_perimeter_provider.dart';
import 'island_settings_provider.dart';

final gameProvider = Provider<IslandGame>((ref) {
  final settings = ref.watch(islandSettingsProvider);
  final showPerimeter = ref.watch(showPerimeterProvider);
  // TODO: Optionally get size from a SizeProvider or pass via GameScreen (see note below)
  return IslandGame(
    amplitude: settings.amplitude,
    wavelength: settings.wavelength,
    bias: settings.bias,
    seed: settings.seed,
    islandRadius: settings.islandRadius,
    gameSize: kDefaultGameSize, // or get from MediaQuery/etc.
    showPerimeter: showPerimeter,
  );
});
