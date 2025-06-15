import 'package:flutter/material.dart';
import '../models/unit_model.dart';

class GameHUD extends StatelessWidget {
  final int blueUnits;
  final int redUnits;
  final double blueHealthPercent;
  final double redHealthPercent;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const GameHUD({
    Key? key,
    required this.blueUnits,
    required this.redUnits,
    required this.blueHealthPercent,
    required this.redHealthPercent,
    required this.isVisible,
    this.onToggleVisibility,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return Positioned(
        top: 50,
        left: 16,
        child: FloatingActionButton(
          mini: true,
          heroTag: "hudToggle",
          backgroundColor: Colors.black.withOpacity(0.7),
          onPressed: onToggleVisibility,
          child: const Icon(Icons.info_outline, color: Colors.white),
        ),
      );
    }

    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.black.withOpacity(0.85),
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
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: onToggleVisibility,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTeamStatus(
                      'Red Team',
                      redUnits,
                      redHealthPercent,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamStatus(
      String teamName, int unitCount, double healthPercent, Color teamColor) {
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
          'Units: $unitCount',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
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
}
