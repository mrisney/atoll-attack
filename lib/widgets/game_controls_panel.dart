// lib/widgets/game_controls_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../models/unit_model.dart';
import '../constants/game_config.dart';

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
          maxWidth: isLandscape ? 600 : 350,
          minWidth: 280,
          maxHeight: isLandscape ? screenSize.height * 0.6 : 220,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: isLandscape
              ? _buildCompactLandscapeLayout(context, unitCounts, game)
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
        // Header
        _buildHeader(),
        const SizedBox(height: 8),
        // Unit counts
        _buildCompactUnitCountDisplay(unitCounts),
        const SizedBox(height: 8),
        // Spawn buttons
        _buildPortraitSpawnButtons(unitCounts, game),
        const SizedBox(height: 4),
        // Instructions
        _buildInstructions(9),
      ],
    );
  }

  Widget _buildCompactLandscapeLayout(
      BuildContext context, Map<String, int> unitCounts, game) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with counts
        Row(
          children: [
            Expanded(child: _buildHeader()),
            _buildLandscapeUnitCounts(unitCounts),
          ],
        ),
        const SizedBox(height: 8),
        // Horizontal spawn buttons
        _buildLandscapeSpawnButtons(unitCounts, game),
        const SizedBox(height: 4),
        _buildInstructions(10),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Spawn Units',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (onClose != null)
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
      ],
    );
  }

  Widget _buildLandscapeUnitCounts(Map<String, int> unitCounts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMiniTeamCount('B', Colors.blue, unitCounts, true),
          const SizedBox(width: 12),
          _buildMiniTeamCount('R', Colors.red, unitCounts, false),
        ],
      ),
    );
  }

  Widget _buildMiniTeamCount(
      String label, Color color, Map<String, int> unitCounts, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 2),
        Text(
          '${unitCounts['${prefix}Remaining']}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactUnitCountDisplay(Map<String, int> unitCounts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTeamInfo('Blue', unitCounts, Colors.blue, true),
          Container(
            height: 35,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildTeamInfo('Red', unitCounts, Colors.red, false),
        ],
      ),
    );
  }

  Widget _buildTeamInfo(
      String team, Map<String, int> unitCounts, Color color, bool isBlue) {
    String prefix = isBlue ? 'blue' : 'red';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        const SizedBox(height: 2),
        Text(
          'C:${unitCounts['${prefix}CaptainsRemaining']} '
          'A:${unitCounts['${prefix}ArchersRemaining']} '
          'S:${unitCounts['${prefix}SwordsmenRemaining']}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 8,
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

  Widget _buildPortraitSpawnButtons(Map<String, int> unitCounts, game) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blue',
                style: TextStyle(color: Colors.blue.shade400, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildUnitButtons(unitCounts, game, Team.blue, false),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Red',
                style: TextStyle(color: Colors.red.shade400, fontSize: 10),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _buildUnitButtons(unitCounts, game, Team.red, false),
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
        // Blue team
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _buildUnitButtons(unitCounts, game, Team.blue, true),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Red team
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _buildUnitButtons(unitCounts, game, Team.red, true),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildUnitButtons(
      Map<String, int> unitCounts, game, Team team, bool isLandscape) {
    final prefix = team == Team.blue ? 'blue' : 'red';
    final baseColor = team == Team.blue ? Colors.blue : Colors.red;

    return [
      _buildCompactButton(
        'C',
        Icons.star,
        baseColor.shade700,
        () => game.spawnSingleUnit(UnitType.captain, team),
        unitCounts['${prefix}CaptainsRemaining']! > 0,
        unitCounts['${prefix}CaptainsRemaining']!,
        isLandscape,
      ),
      _buildCompactButton(
        'A',
        Icons.sports_esports,
        baseColor.shade500,
        () => game.spawnSingleUnit(UnitType.archer, team),
        unitCounts['${prefix}ArchersRemaining']! > 0,
        unitCounts['${prefix}ArchersRemaining']!,
        isLandscape,
      ),
      _buildCompactButton(
        'S',
        Icons.shield,
        baseColor.shade300,
        () => game.spawnSingleUnit(UnitType.swordsman, team),
        unitCounts['${prefix}SwordsmenRemaining']! > 0,
        unitCounts['${prefix}SwordsmenRemaining']!,
        isLandscape,
      ),
    ];
  }

  Widget _buildCompactButton(String label, IconData icon, Color color,
      VoidCallback onPressed, bool enabled, int count, bool isLandscape) {
    final size = isLandscape ? 50.0 : 45.0;
    final iconSize = isLandscape ? 14.0 : 12.0;

    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.shade600,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize, color: Colors.white),
            Text(label,
                style: TextStyle(
                    fontSize: isLandscape ? 9 : 8, color: Colors.white)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: isLandscape ? 8 : 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(double fontSize) {
    return Text(
      'Drag to select • Tap to move • Tap buttons to spawn',
      style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: fontSize,
      ),
      textAlign: TextAlign.center,
    );
  }
}
