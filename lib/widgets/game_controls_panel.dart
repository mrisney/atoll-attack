import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import '../providers/game_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit_model.dart';

class GameControlsPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  const GameControlsPanel({Key? key, this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);

    return Material(
      color: Colors.transparent,
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
            minWidth: 280,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Spawn Units',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Unit count display with breakdown
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      // Blue team breakdown
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Blue: ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'C:${game.blueCaptainsRemaining} A:${game.blueArchersRemaining} S:${game.blueSwordsmenRemaining}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Red team breakdown
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Red: ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'C:${game.redCaptainsRemaining} A:${game.redArchersRemaining} S:${game.redSwordsmenRemaining}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'C=Captain(1) A=Archer(12) S=Swordsman(12)',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Individual unit spawn buttons for Blue team
                const Text(
                  'Spawn Blue Team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUnitButton(
                      context,
                      'Captain',
                      Icons.star,
                      Colors.blue.shade700,
                      () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                      game.blueCaptainsRemaining > 0,
                      '${game.blueCaptainsRemaining}',
                    ),
                    _buildUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.blue.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                      game.blueArchersRemaining > 0,
                      '${game.blueArchersRemaining}',
                    ),
                    _buildUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.blue.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                      game.blueSwordsmenRemaining > 0,
                      '${game.blueSwordsmenRemaining}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Individual unit spawn buttons for Red team
                const Text(
                  'Spawn Red Team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUnitButton(
                      context,
                      'Captain',
                      Icons.star,
                      Colors.red.shade700,
                      () => game.spawnSingleUnit(UnitType.captain, Team.red),
                      game.redCaptainsRemaining > 0,
                      '${game.redCaptainsRemaining}',
                    ),
                    _buildUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.red.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.red),
                      game.redArchersRemaining > 0,
                      '${game.redArchersRemaining}',
                    ),
                    _buildUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.red.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.red),
                      game.redSwordsmenRemaining > 0,
                      '${game.redSwordsmenRemaining}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 75,
      height: 70,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
