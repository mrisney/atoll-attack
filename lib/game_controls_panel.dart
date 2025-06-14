import 'package:flutter/material.dart';

class GameControlsPanel extends StatelessWidget {
  final bool showPerimeter;
  final ValueChanged<bool> onTogglePerimeter;
  final VoidCallback onSpawnUnits;
  final VoidCallback onClose;

  const GameControlsPanel({
    super.key,
    required this.showPerimeter,
    required this.onTogglePerimeter,
    required this.onSpawnUnits,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: onClose,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Show Perimeter',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Switch(
                  value: showPerimeter,
                  onChanged: onTogglePerimeter,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.group),
              label: const Text('Spawn 12 Units'),
              onPressed: onSpawnUnits,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
