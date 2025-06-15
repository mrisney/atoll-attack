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
            maxWidth: 280,
            minWidth: 250,
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

                // Unit count display
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              Text(
                                'Blue: ${game.blueUnitsRemaining}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                              Text(
                                'Red: ${game.redUnitsRemaining}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Text(
                        'remaining',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Individual unit spawn buttons
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
                      game.blueUnitsRemaining > 0,
                    ),
                    _buildUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.blue.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                      game.blueUnitsRemaining > 0,
                    ),
                    _buildUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.blue.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                      game.blueUnitsRemaining > 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                      game.redUnitsRemaining > 0,
                    ),
                    _buildUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.red.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.red),
                      game.redUnitsRemaining > 0,
                    ),
                    _buildUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.red.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.red),
                      game.redUnitsRemaining > 0,
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
  ) {
    return SizedBox(
      width: 70,
      height: 60,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
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
          ],
        ),
      ),
    );
  }
}
