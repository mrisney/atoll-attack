import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import '../providers/game_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit_model.dart';
import '../config.dart';

class GameControlsPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  const GameControlsPanel({Key? key, this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final unitCounts = ref.watch(unitCountsProvider);

    return Material(
      color: Colors.transparent,
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 320,
            minWidth: 300,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
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
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 20),
                      onPressed: onClose,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),

                // Compact unit count display
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Blue team breakdown
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
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
                            'C:${unitCounts['blueCaptainsRemaining']} A:${unitCounts['blueArchersRemaining']} S:${unitCounts['blueSwordsmenRemaining']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total: ${unitCounts['blueRemaining']}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Red team breakdown
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
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
                            'C:${unitCounts['redCaptainsRemaining']} A:${unitCounts['redArchersRemaining']} S:${unitCounts['redSwordsmenRemaining']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Total: ${unitCounts['redRemaining']}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'C=Captain($kMaxCaptainsPerTeam) A=Archer($kMaxArchersPerTeam) S=Swordsman($kMaxSwordsmenPerTeam)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Blue team spawn buttons (more compact)
                const Text(
                  'Spawn Blue Team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactUnitButton(
                      context,
                      'Captain',
                      Icons.star,
                      Colors.blue.shade700,
                      () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                      unitCounts['blueCaptainsRemaining']! > 0,
                      '${unitCounts['blueCaptainsRemaining']}',
                    ),
                    _buildCompactUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.blue.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                      unitCounts['blueArchersRemaining']! > 0,
                      '${unitCounts['blueArchersRemaining']}',
                    ),
                    _buildCompactUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.blue.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                      unitCounts['blueSwordsmenRemaining']! > 0,
                      '${unitCounts['blueSwordsmenRemaining']}',
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Red team spawn buttons (more compact)
                const Text(
                  'Spawn Red Team:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactUnitButton(
                      context,
                      'Captain',
                      Icons.star,
                      Colors.red.shade700,
                      () => game.spawnSingleUnit(UnitType.captain, Team.red),
                      unitCounts['redCaptainsRemaining']! > 0,
                      '${unitCounts['redCaptainsRemaining']}',
                    ),
                    _buildCompactUnitButton(
                      context,
                      'Archer',
                      Icons.sports_esports,
                      Colors.red.shade500,
                      () => game.spawnSingleUnit(UnitType.archer, Team.red),
                      unitCounts['redArchersRemaining']! > 0,
                      '${unitCounts['redArchersRemaining']}',
                    ),
                    _buildCompactUnitButton(
                      context,
                      'Swordsman',
                      Icons.shield,
                      Colors.red.shade300,
                      () => game.spawnSingleUnit(UnitType.swordsman, Team.red),
                      unitCounts['redSwordsmenRemaining']! > 0,
                      '${unitCounts['redSwordsmenRemaining']}',
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

  Widget _buildCompactUnitButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 80,
      height: 55, // Reduced height
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 9,
          ),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 9,
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
