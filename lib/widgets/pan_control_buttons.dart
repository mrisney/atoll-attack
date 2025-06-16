import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';

/// A widget that provides directional pan control buttons for mobile users
class PanControlButtons extends ConsumerWidget {
  const PanControlButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Up button
          IconButton(
            icon: const Icon(Icons.arrow_upward, color: Colors.white),
            onPressed: () => game.panCamera(Vector2(0, 20)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          // Middle row with left, reset, right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => game.panCamera(Vector2(20, 0)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                onPressed: () => game.resetZoom(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                onPressed: () => game.panCamera(Vector2(-20, 0)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          // Down button
          IconButton(
            icon: const Icon(Icons.arrow_downward, color: Colors.white),
            onPressed: () => game.panCamera(Vector2(0, -20)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}