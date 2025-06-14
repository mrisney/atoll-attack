import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'island_component.dart';
import 'unit_component.dart';
import 'dart:math';

class IslandGame extends FlameGame with HasCollisionDetection {
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  bool showPerimeter;

  late IslandComponent _island;
  bool _isLoaded = false;

  IslandGame({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
    required this.islandRadius,
    this.showPerimeter = false,
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
      islandRadius: islandRadius,
      showPerimeter: showPerimeter, // <-- pass the flag here!
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
    required double islandRadius,
    required bool showPerimeter, // <-- add this!
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    this.islandRadius = islandRadius;
    this.showPerimeter = showPerimeter;
    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );
      _island.showPerimeter = showPerimeter; // <-- always set this!
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
        islandRadius: islandRadius,
      );
      _island.showPerimeter = showPerimeter; // <-- always set this!
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Keep perimeter flag in sync
    if (_isLoaded && _island.isMounted) {
      _island.showPerimeter = showPerimeter;
    }
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

  void spawnUnits(int count) {
    if (!_isLoaded || !_island.isMounted) return;
    final rng = Random();
    int attempts = 0, spawned = 0;
    while (spawned < count && attempts < count * 20) {
      final position = Vector2(
        rng.nextDouble() * gameSize.x,
        rng.nextDouble() * gameSize.y,
      );
      if (_island.isOnLand(position)) {
        add(UnitComponent(position: position));
        spawned++;
      }
      attempts++;
    }
  }
}
