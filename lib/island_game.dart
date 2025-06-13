import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart'; // for Vector2
import 'island_component.dart';

/// The main Atoll Wars game using a GPU-accelerated island renderer.
class IslandGame extends FlameGame with HasCollisionDetection {
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  late IslandComponent _island;

  bool _isLoaded = false;

  IslandGame({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
  });

  @override
  Color backgroundColor() => const Color(0xFF1a1a2e);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _island = IslandComponent(
      radius: gameSize.x * 0.3,
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      gameSize: gameSize,
    );
    _island.position = gameSize / 2;
    add(_island);

    _isLoaded = true;
    debugPrint('Island game loaded with size: ${gameSize.x}x${gameSize.y}');
  }

  void updateParameters({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
      );
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    gameSize = newSize;
    if (_isLoaded && _island.isMounted) {
      _island.radius = newSize.x * 0.3;
      _island.position = newSize / 2;
      _island.gameSize = newSize;
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
  }

  double getElevationAt(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getElevationAt(worldPosition);
    }
    return 0.0;
  }

  bool isOnLand(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.isOnLand(worldPosition);
    }
    return false;
  }

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getMovementSpeedMultiplier(worldPosition);
    }
    return 1.0;
  }
}
