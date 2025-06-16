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
  Offset? _position;
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _position = ScreenUtil.getPosition(context, 5, 10);
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
    if (widget.unitsInfo.isEmpty) return const SizedBox.shrink();
    
    if (_position == null) {
      _position = ScreenUtil.getPosition(context, 5, 10);
    }

    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width * 0.35;
    
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
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactHeader(),
                if (_isExpanded)
                  _buildExpandedList(screenSize.height * 0.5)
                else
                  _buildCompactInfo(widget.unitsInfo[_currentIndex]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, color: Colors.white54, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Units (${widget.unitsInfo.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_isExpanded && widget.unitsInfo.length > 1)
            _buildNavigation(),
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.unfold_less : Icons.unfold_more,
              color: Colors.white70,
              size: 14,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 14),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigation() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _previousUnit,
            child: const Icon(Icons.chevron_left, color: Colors.white70, size: 14),
          ),
          Text(
            '${_currentIndex + 1}/${widget.unitsInfo.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          InkWell(
            onTap: _nextUnit,
            child: const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(Map<String, dynamic> unitInfo) {
    final String type = unitInfo['type'] ?? '';
    final String team = unitInfo['team'] ?? '';
    final int health = unitInfo['health'] ?? 0;
    final bool hasFlag = unitInfo['hasFlag'] ?? false;
    
    Color teamColor = team == 'BLUE' ? Colors.blue : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: teamColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$team $type',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasFlag)
                const Icon(Icons.flag, color: Colors.yellow, size: 12),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'HP:',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (health / 100).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: health > 50 ? Colors.green : (health > 25 ? Colors.orange : Colors.red),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$health%',
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedList(double maxHeight) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.builder(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: widget.unitsInfo.length,
        itemBuilder: (context, index) {
          return _buildCompactInfo(widget.unitsInfo[index]);
        },
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
}