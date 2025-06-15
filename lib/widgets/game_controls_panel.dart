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
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 420, // Much wider
          minWidth: 380,
          maxHeight: 180, // Much shorter
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
          padding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 12), // Reduced padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button - more compact
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Spawn Units',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // Smaller font
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 18),
                    onPressed: onClose,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              // Compact unit count display in horizontal layout
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Blue team info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Blue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'C:${unitCounts['blueCaptainsRemaining']} A:${unitCounts['blueArchersRemaining']} S:${unitCounts['blueSwordsmenRemaining']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Total: ${unitCounts['blueRemaining']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Divider
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),

                    // Red team info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Red',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'C:${unitCounts['redCaptainsRemaining']} A:${unitCounts['redArchersRemaining']} S:${unitCounts['redSwordsmenRemaining']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'Total: ${unitCounts['redRemaining']}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Divider
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),

                    // Legend
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Legend',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'C=Captain($kMaxCaptainsPerTeam)',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'A=Archer($kMaxArchersPerTeam)',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'S=Swordsman($kMaxSwordsmenPerTeam)',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Spawn buttons in horizontal layout - much more compact
              Row(
                children: [
                  // Blue team spawn buttons
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Blue Team:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCompactUnitButton(
                              context,
                              'C',
                              Icons.star,
                              Colors.blue.shade700,
                              () => game.spawnSingleUnit(
                                  UnitType.captain, Team.blue),
                              unitCounts['blueCaptainsRemaining']! > 0,
                              '${unitCounts['blueCaptainsRemaining']}',
                            ),
                            _buildCompactUnitButton(
                              context,
                              'A',
                              Icons.sports_esports,
                              Colors.blue.shade500,
                              () => game.spawnSingleUnit(
                                  UnitType.archer, Team.blue),
                              unitCounts['blueArchersRemaining']! > 0,
                              '${unitCounts['blueArchersRemaining']}',
                            ),
                            _buildCompactUnitButton(
                              context,
                              'S',
                              Icons.shield,
                              Colors.blue.shade300,
                              () => game.spawnSingleUnit(
                                  UnitType.swordsman, Team.blue),
                              unitCounts['blueSwordsmenRemaining']! > 0,
                              '${unitCounts['blueSwordsmenRemaining']}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Red team spawn buttons
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Red Team:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildCompactUnitButton(
                              context,
                              'C',
                              Icons.star,
                              Colors.red.shade700,
                              () => game.spawnSingleUnit(
                                  UnitType.captain, Team.red),
                              unitCounts['redCaptainsRemaining']! > 0,
                              '${unitCounts['redCaptainsRemaining']}',
                            ),
                            _buildCompactUnitButton(
                              context,
                              'A',
                              Icons.sports_esports,
                              Colors.red.shade500,
                              () => game.spawnSingleUnit(
                                  UnitType.archer, Team.red),
                              unitCounts['redArchersRemaining']! > 0,
                              '${unitCounts['redArchersRemaining']}',
                            ),
                            _buildCompactUnitButton(
                              context,
                              'S',
                              Icons.shield,
                              Colors.red.shade300,
                              () => game.spawnSingleUnit(
                                  UnitType.swordsman, Team.red),
                              unitCounts['redSwordsmenRemaining']! > 0,
                              '${unitCounts['redSwordsmenRemaining']}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Instructions
              const SizedBox(height: 4),
              Text(
                'Drag to select units • Click to move selected units • Tap empty space to spawn',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
      width: 50, // Much smaller width
      height: 45, // Much smaller height
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 8,
          ),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 8),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
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
