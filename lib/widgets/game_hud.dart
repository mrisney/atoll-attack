// lib/widgets/game_hud.dart
import 'package:flutter/material.dart';

class GameHUD extends StatelessWidget {
  final int blueUnits;
  final int redUnits;
  final double blueHealthPercent;
  final double redHealthPercent;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;
  final int blueUnitsRemaining;
  final int redUnitsRemaining;

  const GameHUD({
    Key? key,
    required this.blueUnits,
    required this.redUnits,
    required this.blueHealthPercent,
    required this.redHealthPercent,
    required this.isVisible,
    this.onToggleVisibility,
    required this.blueUnitsRemaining,
    required this.redUnitsRemaining,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return GestureDetector(
        onTap: onToggleVisibility,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Battle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggleVisibility,
                  child:
                      const Icon(Icons.close, color: Colors.white70, size: 16),
                ),
              ],
            ),
          ),
          // Compact team stats
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCompactTeamStatus(
                  blueUnits,
                  blueHealthPercent,
                  Colors.blue,
                  blueUnitsRemaining,
                ),
                const SizedBox(width: 12),
                _buildCompactTeamStatus(
                  redUnits,
                  redHealthPercent,
                  Colors.red,
                  redUnitsRemaining,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTeamStatus(
      int units, double health, Color color, int remaining) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$units/$remaining',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Compact health bar
        Container(
          width: 50,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: health.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: health > 0.5
                    ? Colors.green
                    : health > 0.25
                        ? Colors.orange
                        : Colors.red,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
