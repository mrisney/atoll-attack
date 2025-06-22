import 'package:flutter/material.dart';
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
  State<DraggableSelectedUnitsPanel> createState() =>
      _DraggableSelectedUnitsPanelState();
}

class _DraggableSelectedUnitsPanelState
    extends State<DraggableSelectedUnitsPanel> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Offset? _position;
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;

  // Keep track of panel boundaries to prevent going off-screen
  double _minX = 0;
  double _minY = 0;
  double _maxX = 0;
  double _maxY = 0;

  // Track previous orientation to detect changes
  Orientation? _previousOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recalculate boundaries when screen size changes (e.g., rotation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBoundariesForCurrentOrientation();
    });
  }

  @override
  void didChangeMetrics() {
    // Called when screen metrics change (including rotation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleOrientationChange();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  void _initializePosition() {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final isLandscape = screenSize.width > screenSize.height;

    // Calculate panel dimensions for boundary calculation
    final panelWidth = isLandscape
        ? math.min(280.0, screenSize.width * 0.25)
        : math.min(200.0, screenSize.width * 0.45);
    final panelHeight = math.min(screenSize.height * 0.5, 300.0);

    // Set boundaries with panel dimensions in mind
    _minX = safeArea.left;
    _minY = safeArea.top;
    _maxX = screenSize.width - panelWidth - safeArea.right;
    _maxY = screenSize.height - panelHeight - safeArea.bottom;

    setState(() {
      // Start position avoids the Battle Status panel
      // In portrait: below the Battle Status (approximately 200px from top)
      // In landscape: right side of screen
      if (isLandscape) {
        _position = Offset(
          screenSize.width * 0.65, // Right side
          _minY + 60, // Below top controls
        );
      } else {
        _position = Offset(
          _minX + 10, // Left side
          _minY + 200, // Below Battle Status panel
        );
      }

      _previousOrientation = MediaQuery.of(context).orientation;
    });
  }

  void _updateBoundariesForCurrentOrientation() {
    if (!mounted) return;

    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final isLandscape = screenSize.width > screenSize.height;

    // Calculate panel dimensions for boundary calculation
    final panelWidth = isLandscape
        ? math.min(280.0, screenSize.width * 0.25)
        : math.min(200.0, screenSize.width * 0.45);
    final panelHeight = math.min(screenSize.height * 0.5, 300.0);

    // Set boundaries with panel dimensions in mind
    final newMinX = safeArea.left;
    final newMinY = safeArea.top;
    final newMaxX = screenSize.width - panelWidth - safeArea.right;
    final newMaxY = screenSize.height - panelHeight - safeArea.bottom;

    setState(() {
      _minX = newMinX;
      _minY = newMinY;
      _maxX = newMaxX;
      _maxY = newMaxY;

      // If we have a position, ensure it's still within bounds after rotation
      if (_position != null) {
        final clampedX = _position!.dx.clamp(_minX, _maxX);
        final clampedY = _position!.dy.clamp(_minY, _maxY);

        // If position needs adjustment, update it
        if (clampedX != _position!.dx || clampedY != _position!.dy) {
          _position = Offset(clampedX, clampedY);
        }
      }
    });
  }

  void _handleOrientationChange() {
    if (!mounted) return;

    final currentOrientation = MediaQuery.of(context).orientation;

    // Only handle if orientation actually changed
    if (_previousOrientation != null &&
        _previousOrientation != currentOrientation) {
      final screenSize = MediaQuery.of(context).size;
      final safeArea = MediaQuery.of(context).padding;
      final isLandscape = currentOrientation == Orientation.landscape;

      // Update boundaries first
      _updateBoundariesForCurrentOrientation();

      // Calculate a smart new position based on the new orientation
      if (_position != null) {
        setState(() {
          if (isLandscape) {
            // Moving to landscape: position on the right side
            _position = Offset(
              screenSize.width * 0.65,
              math.min(_position!.dy, _maxY),
            );
          } else {
            // Moving to portrait: position on the left side, below status panel
            _position = Offset(
              _minX + 10,
              math.max(_minY + 200, math.min(_position!.dy, _maxY)),
            );
          }
        });
      }
    }

    _previousOrientation = currentOrientation;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unitsInfo.isEmpty) return const SizedBox.shrink();

    // Reset currentIndex if it's out of bounds
    if (_currentIndex >= widget.unitsInfo.length) {
      _currentIndex = 0;
    }

    if (_position == null) {
      _initializePosition();
      return const SizedBox.shrink(); // Don't render until position is set
    }

    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;

    // Store current orientation
    _previousOrientation = MediaQuery.of(context).orientation;

    // Responsive width based on screen orientation
    final width =
        isLandscape ? screenSize.width * 0.25 : screenSize.width * 0.45;

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
              maxWidth: isLandscape ? 280 : 200, // More compact max width
              maxHeight: screenSize.height * 0.5, // Reduced max height
              minWidth: 160, // Minimum width
            ),
            decoration: BoxDecoration(
              color:
                  Colors.black.withOpacity(0.5), // More transparent (was 0.7)
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.2), // More subtle border
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3), // Lighter shadow
                  blurRadius: 6,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompactHeader(),
                if (_isExpanded)
                  _buildExpandedList(screenSize.height * 0.4)
                else if (widget.unitsInfo.isNotEmpty)
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle visual indicator
          Container(
            width: 20,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
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
          // Fixed navigation section to prevent overflow
          if (!_isExpanded && widget.unitsInfo.length > 1) _buildNavigation(),
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
    return SizedBox(
      width: 60, // Fixed width to prevent overflow
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: InkWell(
              onTap: _previousUnit,
              child: const Icon(Icons.chevron_left,
                  color: Colors.white70, size: 12),
            ),
          ),
          Expanded(
            child: Text(
              '${_currentIndex + 1}/${widget.unitsInfo.length}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9, // Reduced font size to fit better
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 16,
            height: 16,
            child: InkWell(
              onTap: _nextUnit,
              child: const Icon(Icons.chevron_right,
                  color: Colors.white70, size: 12),
            ),
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
    final String id = unitInfo['id'] ?? '';
    final bool isTargeted = unitInfo['isTargeted'] ?? false;

    Color teamColor = team == 'BLUE' ? Colors.blue : Colors.red;

    // Highlight the current unit in expanded view
    final bool isCurrentUnit = _isExpanded &&
        widget.unitsInfo.indexWhere((info) => info['id'] == id) ==
            _currentIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isCurrentUnit
            ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
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
                    fontWeight:
                        isCurrentUnit ? FontWeight.bold : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasFlag)
                const Icon(Icons.flag, color: Colors.yellow, size: 12),
              if (isTargeted)
                const Icon(Icons.gps_fixed, color: Colors.grey, size: 12),
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
                        color: health > 50
                            ? Colors.green
                            : (health > 25 ? Colors.orange : Colors.red),
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
        color: Colors.black.withOpacity(0.3),
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
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });
              },
              child: _buildCompactInfo(widget.unitsInfo[index]),
            );
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
      _currentIndex = (_currentIndex - 1 + widget.unitsInfo.length) %
          widget.unitsInfo.length;

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
