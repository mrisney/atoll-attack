// lib/island_game.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'island_component.dart';

class IslandGame extends FlameGame with HasCollisionDetection {
  double amplitude;
  double wavelength;
  double bias;
  // Removed blur parameter - hardcoded in shader
  int seed;
  late IslandComponent _island;

  // Track if the game has been fully loaded
  bool _isLoaded = false;

  IslandGame({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    // Removed blur parameter
    required this.seed,
  });

  @override
  Color backgroundColor() => const Color(0xFF1a1a2e); // Dark background

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create the island component
    _island = IslandComponent(
      radius: size.x * 0.3,
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      // Removed blur parameter
      seed: seed,
      gameSize: size,
    );

    // Position the island in the center
    _island.position = size / 2;

    // Add the island to the game
    add(_island);

    _isLoaded = true;
    print('Island game loaded with size: ${size.x}x${size.y}');
  }

  void updateParameters({
    required double amplitude,
    required double wavelength,
    required double bias,
    // Removed blur parameter
    required int seed,
  }) {
    // Update local parameters
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    // Removed blur assignment
    this.seed = seed;

    // Update the island component if it exists and game is loaded
    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        // Removed blur parameter
        seed: seed,
      );
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    // Update island size and position when screen size changes
    if (_isLoaded && _island.isMounted) {
      _island.radius = newSize.x * 0.3;
      _island.position = newSize / 2;
      _island.gameSize = newSize;

      // Trigger a painter update with new size
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        // Removed blur parameter
        seed: seed,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // No time-based updates needed for GPU rendering
  }

  // Get elevation at world position (useful for gameplay)
  double getElevationAt(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getElevationAt(worldPosition);
    }
    return 0.0;
  }

  // Check if a position is on land (useful for gameplay)
  bool isOnLand(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.isOnLand(worldPosition);
    }
    return false;
  }

  // Get movement speed multiplier for gameplay
  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getMovementSpeedMultiplier(worldPosition);
    }
    return 1.0;
  }
}
