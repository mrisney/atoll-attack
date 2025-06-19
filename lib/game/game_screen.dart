// lib/game/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/island_game.dart';
import 'package:flame/extensions.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late IslandGame _game;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    // Create game without initial size - Flame will handle it
    _game = IslandGame(
      amplitude: 0.5,
      wavelength: 1.0,
      bias: 0.0,
      seed: 42,
      gameSize: Vector2.zero(), // Will be set by Flame
      islandRadius: 0.7,
      showPerimeter: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _baseZoom = _game.camera.viewfinder.zoom;
      },
      onScaleUpdate: (details) {
        if (details.pointerCount < 2) return;
        final newZoom =
            (_baseZoom * details.scale).clamp(_game.minZoom, _game.maxZoom);
        _game.zoomAt(newZoom, details.focalPoint.toVector2());
      },
      child: GameWidget(game: _game),
    );
  }
}

// Helper extension
extension OffsetToVector2 on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}
