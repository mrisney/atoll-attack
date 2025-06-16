import 'package:flutter/material.dart';
import '../utils/screen_util.dart';
import '../utils/responsive_size_util.dart';
import 'dart:math' as math;

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
  
  // Keep track of panel boundaries to prevent going off-screen
  double _minX = 0;
  double _minY = 0;
  double _maxX = 0;
  double _maxY = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
    });
  }
  
  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    
    // Set boundaries
    _minX = safeArea.left;
    _minY = safeArea.top;
    _maxX = screenSize.width - (screenSize.width * 0.25) - safeArea.right;
    _maxY = screenSize.height - 100 - safeArea.bottom;
    
    setState(() {
      // Start at top-left with some padding
      _position = Offset(
        _minX + 10,
        _minY + 10
      );
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
      _initializePosition();
    }

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    // Responsive width based on screen orientation
    final width = isLandscape 
        ? screenSize.width * 0.25 
        : screenSize.width * 0.4;
    
    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Calculate new position with boundary constraints
            final newX = (_position!.dx + details.delta.dx).clamp(_minX, _maxX);
            final newY = (_position!.dy + details.delta.dy).clamp(_minY, _maxY);
            
            _position = Offset(newX, newY);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            constraints: BoxConstraints(
              maxWidth: isLandscape ? 300 : width,
              maxHeight: screenSize.height * 0.7,
            ),
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
                  _buildExpandedList(screenSize.height * 0.4)
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
    // Get team color
    final Color headerColor = widget.unitsInfo.isEmpty 
        ? Colors.blue.withOpacity(0.7)
        : (widget.unitsInfo.first['team'] == 'BLUE' ? Colors.blue : Colors.red).withOpacity(0.7);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.drag_indicator, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
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
            Flexible(child: _buildNavigation()),
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              icon: Icon(
                _isExpanded ? Icons.unfold_less : Icons.unfold_more,
                color: Colors.white70,
                size: 14,
              ),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 20,
            height: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 14),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNavigation() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _previousUnit,
          child: const Icon(Icons.chevron_left, color: Colors.white70, size: 14),
        ),
        Text(
          '${_currentIndex + 1}/${widget.unitsInfo.length}',
          style: const TextStyle(
            color: Colors.white70, 
            fontSize: 10,
          ),
        ),
        InkWell(
          onTap: _nextUnit,
          child: const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
        ),
      ],
    );
  }

  Widget _buildCompactInfo(Map<String, dynamic> unitInfo) {
    final String type = unitInfo['type'] ?? '';
    final String team = unitInfo['team'] ?? '';
    final int health = unitInfo['health'] ?? 0;
    final bool hasFlag = unitInfo['hasFlag'] ?? false;
    final String id = unitInfo['id'] ?? '';
    
    Color teamColor = team == 'BLUE' ? Colors.blue : Colors.red;
    
    // Highlight the current unit in expanded view
    final bool isCurrentUnit = _isExpanded && 
        widget.unitsInfo.indexWhere((info) => info['id'] == id) == _currentIndex;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: isCurrentUnit 
            ? teamColor.withOpacity(0.2) 
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isCurrentUnit 
            ? Border.all(color: teamColor.withOpacity(0.5), width: 1) 
            : null,
      ),
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: isCurrentUnit ? FontWeight.bold : FontWeight.w600,
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
    // Calculate a safer height that won't overflow
    final screenSize = MediaQuery.of(context).size;
    final safeHeight = math.min(maxHeight, screenSize.height * 0.3);
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: safeHeight,
        minHeight: 50,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 4,
        radius: const Radius.circular(4),
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: widget.unitsInfo.length,
          itemBuilder: (context, index) {
            return _buildCompactInfo(widget.unitsInfo[index]);
          },
        ),
      ),
    );
  }

  void _nextUnit() {
    if (widget.unitsInfo.isEmpty) return;
    
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.unitsInfo.length;
      
      // If in expanded mode, scroll to the selected item
      if (_isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentIndex();
        });
      }
    });
  }

  void _previousUnit() {
    if (widget.unitsInfo.isEmpty) return;
    
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.unitsInfo.length) % widget.unitsInfo.length;
      
      // If in expanded mode, scroll to the selected item
      if (_isExpanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToCurrentIndex();
        });
      }
    });
  }
  
  void _scrollToCurrentIndex() {
    if (!_scrollController.hasClients) return;
    
    // Calculate approximate position of the item
    final itemHeight = 50.0; // Estimated height of each item
    final offset = _currentIndex * itemHeight;
    
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}