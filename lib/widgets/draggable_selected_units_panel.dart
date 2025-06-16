import 'package:flutter/material.dart';
import '../utils/screen_util.dart';

class DraggableSelectedUnitsPanel extends StatefulWidget {
  final List<Map<String, dynamic>> unitsInfo;
  final VoidCallback? onClose;

  const DraggableSelectedUnitsPanel({
    Key? key,
    required this.unitsInfo,
    this.onClose,
  }) : super(key: key);

  @override
  State<DraggableSelectedUnitsPanel> createState() => _DraggableSelectedUnitsPanelState();
}

class _DraggableSelectedUnitsPanelState extends State<DraggableSelectedUnitsPanel> {
  int _currentIndex = 0;
  Offset? _position; // Will be initialized based on screen size
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Initialize position after first frame when we have access to screen size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _position = ScreenUtil.getPosition(context, 5, 10); // 5% from left, 10% from top
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unitsInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Use screen size for positioning if not yet set
    if (_position == null) {
      _position = ScreenUtil.getPosition(context, 5, 10); // 5% from left, 10% from top
    }

    final screenSize = MediaQuery.of(context).size;
    final maxHeight = screenSize.height * 0.6; // Limit height to 60% of screen

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position!.dx + details.delta.dx,
              _position!.dy + details.delta.dy,
            );
          });
        },
        child: Card(
          color: Colors.black.withOpacity(0.6),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screenSize.width * 0.6,
              maxHeight: _isExpanded ? maxHeight : double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _isExpanded 
                      ? _buildExpandedView(maxHeight)
                      : _buildUnitInfo(widget.unitsInfo[_currentIndex]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.drag_indicator,
          color: Colors.white54,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Selected Units (${widget.unitsInfo.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.unfold_less : Icons.unfold_more,
            color: Colors.white70,
            size: 16,
          ),
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
        const Spacer(),
        if (!_isExpanded && widget.unitsInfo.length > 1) ...[
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
    );
  }

  Widget _buildExpandedView(double maxHeight) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight - 60, // Account for header and padding
      ),
      width: MediaQuery.of(context).size.width * 0.5,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: widget.unitsInfo.length,
          separatorBuilder: (context, index) => const Divider(
            color: Colors.white24,
            height: 16,
          ),
          itemBuilder: (context, index) {
            return _buildUnitInfo(widget.unitsInfo[index]);
          },
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
        // Add additional unit stats if needed
        if (_isExpanded) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Type: ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              Text(
                _getUnitTypeDescription(type),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          if (hasFlag)
            const Text(
              '🏁 Flag planted at apex!',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ],
    );
  }
  
  String _getUnitTypeDescription(String type) {
    switch (type) {
      case 'CAPTAIN':
        return 'Leader unit - can plant flag at apex';
      case 'ARCHER':
        return 'Ranged attacker - higher ground increases range';
      case 'SWORDSMAN':
        return 'Melee fighter - strong defense when stationary';
      default:
        return type;
    }
  }
}