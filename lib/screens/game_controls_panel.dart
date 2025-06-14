import 'package:flutter/material.dart';

class GameControlsPanel extends StatelessWidget {
  final bool showPerimeter;
  final ValueChanged<bool> onTogglePerimeter;
  final VoidCallback onSpawnUnits;
  final VoidCallback onClose;

  const GameControlsPanel({
    Key? key,
    required this.showPerimeter,
    required this.onTogglePerimeter,
    required this.onSpawnUnits,
    required this.onClose,
  }) : super(key: key);

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
                const Text(
                  'Show Perimeter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: showPerimeter,
                  onChanged: onTogglePerimeter,
                  activeColor: Colors.deepPurple,
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white24,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
