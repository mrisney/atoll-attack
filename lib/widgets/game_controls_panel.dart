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
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isLandscape
              ? screenSize.width * 0.6 // 60% of screen width in landscape
              : screenSize.width * 0.95, // 95% of screen width in portrait
          minWidth: isLandscape ? 400 : 320,
          maxHeight: isLandscape
              ? screenSize.height * 0.8 // 80% of screen height in landscape
              : 200, // Reduced height to prevent overflow
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isLandscape ? 12 : 6, // Reduced padding
            horizontal: isLandscape ? 16 : 12,
          ),
          child: isLandscape
              ? _buildLandscapeLayout(context, unitCounts, game)
              : _buildPortraitLayout(context, unitCounts, game),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
      BuildContext context, Map<String, int> unitCounts, game) {
    return Column(
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
                fontSize: 13, // Slightly smaller
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 16),
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: EdgeInsets.zero,
            ),
          ],
        ),

        // Compact unit count display
        _buildCompactUnitCountDisplay(unitCounts),
        const SizedBox(height: 6), // Reduced spacing

        // Spawn buttons in horizontal layout
        _buildSpawnButtons(unitCounts, game),

        // Instructions - smaller and more compact
        const SizedBox(height: 2),
        Text(
          'Drag to select • Click to move • Tap empty space to spawn',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 8, // Smaller text
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(
      BuildContext context, Map<String, int> unitCounts, game) {
    return Column(
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
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: onClose,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Extended unit count display for landscape
        _buildExtendedUnitCountDisplay(unitCounts),
        const SizedBox(height: 16),

        // Larger spawn buttons for landscape
        _buildLandscapeSpawnButtons(unitCounts, game),

        // Instructions
        const SizedBox(height: 8),
        Text(
          'Drag to select units • Click to move selected units • Tap empty space to spawn units',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompactUnitCountDisplay(Map<String, int> unitCounts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo('Blue', unitCounts, Colors.blue, true),
          Container(
            height: 35, // Reduced height
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildTeamInfo('Red', unitCounts, Colors.red, false),
          Container(
            height: 35, // Reduced height
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildCompactLegend(),
        ],
      ),
    );
  }

  Widget _buildExtendedUnitCountDisplay(Map<String, int> unitCounts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildDetailedTeamInfo(
                  'Blue Team', unitCounts, Colors.blue, true)),
          const SizedBox(width: 20),
          Container(height: 60, width: 1, color: Colors.white.withOpacity(0.3)),
          const SizedBox(width: 20),
          Expanded(
              child: _buildDetailedTeamInfo(
                  'Red Team', unitCounts, Colors.red, false)),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(
      String team, Map<String, int> unitCounts, Color color, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              team,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          'C:${unitCounts['${prefix}CaptainsRemaining']} A:${unitCounts['${prefix}ArchersRemaining']} S:${unitCounts['${prefix}SwordsmenRemaining']}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          'Total: ${unitCounts['${prefix}Remaining']}',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedTeamInfo(
      String teamName, Map<String, int> unitCounts, Color color, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Captains:', style: _labelStyle),
            Text('${unitCounts['${prefix}CaptainsRemaining']}',
                style: _valueStyle),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Archers:', style: _labelStyle),
            Text('${unitCounts['${prefix}ArchersRemaining']}',
                style: _valueStyle),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Swordsmen:', style: _labelStyle),
            Text('${unitCounts['${prefix}SwordsmenRemaining']}',
                style: _valueStyle),
          ],
        ),
      ],
    );
  }

  TextStyle get _labelStyle =>
      const TextStyle(color: Colors.white70, fontSize: 12);
  TextStyle get _valueStyle => const TextStyle(
      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600);

  Widget _buildCompactLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Legend',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'C=Captain($kMaxCaptainsPerTeam)',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 7,
          ),
        ),
        Text(
          'A=Archer($kMaxArchersPerTeam)',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 7,
          ),
        ),
        Text(
          'S=Swords($kMaxSwordsmenPerTeam)',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 7,
          ),
        ),
      ],
    );
  }

  Widget _buildSpawnButtons(Map<String, int> unitCounts, game) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Blue Team:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactUnitButton(
                    'C',
                    Icons.star,
                    Colors.blue.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                    unitCounts['blueCaptainsRemaining']! > 0,
                    '${unitCounts['blueCaptainsRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'A',
                    Icons.sports_esports,
                    Colors.blue.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                    unitCounts['blueArchersRemaining']! > 0,
                    '${unitCounts['blueArchersRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'S',
                    Icons.shield,
                    Colors.blue.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                    unitCounts['blueSwordsmenRemaining']! > 0,
                    '${unitCounts['blueSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Red Team:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCompactUnitButton(
                    'C',
                    Icons.star,
                    Colors.red.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.red),
                    unitCounts['redCaptainsRemaining']! > 0,
                    '${unitCounts['redCaptainsRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'A',
                    Icons.sports_esports,
                    Colors.red.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.red),
                    unitCounts['redArchersRemaining']! > 0,
                    '${unitCounts['redArchersRemaining']}',
                  ),
                  _buildCompactUnitButton(
                    'S',
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
      ],
    );
  }

  Widget _buildLandscapeSpawnButtons(Map<String, int> unitCounts, game) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              const Text(
                'Blue Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLargeUnitButton(
                    'Captain',
                    Icons.star,
                    Colors.blue.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.blue),
                    unitCounts['blueCaptainsRemaining']! > 0,
                    '${unitCounts['blueCaptainsRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Archer',
                    Icons.sports_esports,
                    Colors.blue.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.blue),
                    unitCounts['blueArchersRemaining']! > 0,
                    '${unitCounts['blueArchersRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Swordsman',
                    Icons.shield,
                    Colors.blue.shade300,
                    () => game.spawnSingleUnit(UnitType.swordsman, Team.blue),
                    unitCounts['blueSwordsmenRemaining']! > 0,
                    '${unitCounts['blueSwordsmenRemaining']}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              const Text(
                'Red Team',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLargeUnitButton(
                    'Captain',
                    Icons.star,
                    Colors.red.shade700,
                    () => game.spawnSingleUnit(UnitType.captain, Team.red),
                    unitCounts['redCaptainsRemaining']! > 0,
                    '${unitCounts['redCaptainsRemaining']}',
                  ),
                  _buildLargeUnitButton(
                    'Archer',
                    Icons.sports_esports,
                    Colors.red.shade500,
                    () => game.spawnSingleUnit(UnitType.archer, Team.red),
                    unitCounts['redArchersRemaining']! > 0,
                    '${unitCounts['redArchersRemaining']}',
                  ),
                  _buildLargeUnitButton(
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
      ],
    );
  }

  Widget _buildCompactUnitButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 45, // Reduced width
      height: 40, // Reduced height
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 7,
          ),
          elevation: enabled ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 10),
            Text(label, style: const TextStyle(fontSize: 7)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 7,
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

  Widget _buildLargeUnitButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled,
    String count,
  ) {
    return SizedBox(
      width: 80,
      height: 60,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          elevation: enabled ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            Text(label, style: const TextStyle(fontSize: 10)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  fontSize: 10,
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
