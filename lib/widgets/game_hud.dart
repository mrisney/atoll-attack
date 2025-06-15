import 'package:flutter/material.dart';
import '../models/unit_model.dart';

class GameHUD extends StatelessWidget {
  final int blueUnits;
  final int redUnits;
  final double blueHealthPercent;
  final double redHealthPercent;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final UnitModel? selectedUnit;
  final int blueUnitsRemaining;
  final int redUnitsRemaining;
  final bool showPerimeter;
  final ValueChanged<bool>? onPerimeterToggle;

  const GameHUD({
    Key? key,
    required this.blueUnits,
    required this.redUnits,
    required this.blueHealthPercent,
    required this.redHealthPercent,
    required this.isVisible,
    this.onToggleVisibility,
    this.selectedUnit,
    required this.blueUnitsRemaining,
    required this.redUnitsRemaining,
    required this.showPerimeter,
    this.onPerimeterToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return FloatingActionButton(
        mini: true,
        heroTag: "hudToggle",
        backgroundColor: Colors.black.withOpacity(0.5),
        onPressed: onToggleVisibility,
        child: const Icon(Icons.info_outline, color: Colors.white),
      );
    }

    return Column(
      children: [
        // Main battle status card with perimeter toggle
        Card(
          color: Colors.black.withOpacity(0.4), // More transparent
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Battle Status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Perimeter toggle moved here
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.terrain,
                                color: Colors.white.withOpacity(0.7),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Topographic',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 16,
                                child: Switch(
                                  value: showPerimeter,
                                  onChanged: onPerimeterToggle,
                                  activeColor: Colors.purple.shade300,
                                  inactiveThumbColor: Colors.grey.shade400,
                                  inactiveTrackColor:
                                      Colors.grey.withOpacity(0.2),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white70, size: 20),
                          onPressed: onToggleVisibility,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTeamStatus(
                        'Blue Team',
                        blueUnits,
                        blueHealthPercent,
                        Colors.blue,
                        blueUnitsRemaining,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTeamStatus(
                        'Red Team',
                        redUnits,
                        redHealthPercent,
                        Colors.red,
                        redUnitsRemaining,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // We'll use the SelectedUnitsPanel widget instead of this
      ],
    );
  }

  Widget _buildTeamStatus(String teamName, int unitCount, double healthPercent,
      Color teamColor, int unitsRemaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              teamName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Active: $unitCount',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        Text(
          'Remaining: $unitsRemaining',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text(
              'Health: ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: healthPercent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: healthPercent > 0.5
                          ? Colors.green
                          : healthPercent > 0.25
                              ? Colors.orange
                              : Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(healthPercent * 100).round()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedUnitInfo(UnitModel unit) {
    String unitTypeName = switch (unit.type) {
      UnitType.captain => 'Captain',
      UnitType.swordsman => 'Swordsman',
      UnitType.archer => 'Archer',
    };

    String unitTeamName = unit.team == Team.blue ? 'Blue' : 'Red';
    Color teamColor = unit.team == Team.blue ? Colors.blue : Colors.red;
    double healthPercent = unit.health / unit.maxHealth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$unitTeamName $unitTypeName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (unit.hasPlantedFlag)
              const Icon(
                Icons.flag,
                color: Colors.yellow,
                size: 16,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'Health: ',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: healthPercent.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: healthPercent > 0.5
                          ? Colors.green
                          : healthPercent > 0.25
                              ? Colors.orange
                              : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${unit.health.round()}/${unit.maxHealth.round()}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        if (unit.attackPower > 0) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Attack: ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                '${unit.attackPower.round()}',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Defense: ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                '${unit.defense.round()}',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
