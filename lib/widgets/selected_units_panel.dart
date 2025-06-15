import 'package:flutter/material.dart';

class SelectedUnitsPanel extends StatefulWidget {
  final List<Map<String, dynamic>> unitsInfo;
  final VoidCallback? onClose;

  const SelectedUnitsPanel({
    Key? key,
    required this.unitsInfo,
    this.onClose,
  }) : super(key: key);

  @override
  State<SelectedUnitsPanel> createState() => _SelectedUnitsPanelState();
}

class _SelectedUnitsPanelState extends State<SelectedUnitsPanel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.unitsInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Selected Units (${widget.unitsInfo.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.unitsInfo.length > 1) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 16),
                    onPressed: _previousUnit,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_currentIndex + 1}/${widget.unitsInfo.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    onPressed: _nextUnit,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  onPressed: widget.onClose,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildUnitInfo(widget.unitsInfo[_currentIndex]),
          ],
        ),
      ),
    );
  }

  void _nextUnit() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.unitsInfo.length;
    });
  }

  void _previousUnit() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.unitsInfo.length) % widget.unitsInfo.length;
    });
  }

  Widget _buildUnitInfo(Map<String, dynamic> unitInfo) {
    final String type = unitInfo['type'] ?? '';
    final String team = unitInfo['team'] ?? '';
    final int health = unitInfo['health'] ?? 0;
    final bool hasFlag = unitInfo['hasFlag'] ?? false;
    
    Color teamColor = team == 'BLUE' ? Colors.blue : Colors.red;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              '$team $type',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (hasFlag)
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
                  widthFactor: (health / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: health > 50
                          ? Colors.green
                          : health > 25
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
              '$health%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }
}