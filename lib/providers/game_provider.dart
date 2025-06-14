import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/components.dart'; // for Vector2
import '../models/island_settings.dart';
import '../game/island_game.dart';
import 'show_perimeter_provider.dart';

final gameProvider = Provider<IslandGame>((ref) {
  final settings = ref.watch(islandSettingsProvider);
  final showPerimeter = ref.watch(showPerimeterProvider);
  // Use a fixed size or get from MediaQuery elsewhere
  return IslandGame(
    amplitude: settings.amplitude,
    wavelength: settings.wavelength,
    bias: settings.bias,
    seed: settings.seed,
    islandRadius: settings.islandRadius,
    gameSize: Vector2(400, 900),
    showPerimeter: showPerimeter,
  );
});
