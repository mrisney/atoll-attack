// lib/game/game_screen.dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../game/island_game.dart';
import 'package:flame/extensions.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late IslandGame _game;
  double _baseZoom = 1.0;
  Offset? _lastFocalPoint;
  bool _stickySelection = false;

  @override
  void initState() {
    super.initState();
    // Create game without initial size - Flame will handle it
    _game = IslandGame(
      amplitude: 0.5,
      wavelength: 1.0,
      bias: 0.0,
      seed: 42,
      gameSize: Vector2.zero(), // Will be set by Flame
      islandRadius: 0.7,
      showPerimeter: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _baseZoom = _game.zoomLevel;
              _lastFocalPoint = details.localFocalPoint;
            },
            onScaleUpdate: (details) {
              if (details.pointerCount == 2) {
                // Two-finger zoom
                final newZoom = (_baseZoom * details.scale).clamp(_game.minZoom, _game.maxZoom);
                _game.zoomAt(newZoom, details.localFocalPoint.toVector2());
              } else if (details.pointerCount == 1 && _lastFocalPoint != null) {
                // Single finger pan
                final delta = details.localFocalPoint - _lastFocalPoint!;
                _game.cameraOrigin -= delta.toVector2() / _game.zoomLevel;
                _game.clampCamera();
                _lastFocalPoint = details.localFocalPoint;
              }
            },
            onScaleEnd: (details) {
              _lastFocalPoint = null;
            },
            child: GameWidget(game: _game),
          ),
          
          // Selection controls (top left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clear selection button
                _buildControlButton(
                  icon: Icons.clear,
                  label: 'Clear',
                  onPressed: () {
                    _game.clearSelection();
                  },
                ),
                const SizedBox(height: 8),
                // Sticky selection toggle
                _buildControlButton(
                  icon: _stickySelection ? Icons.push_pin : Icons.push_pin_outlined,
                  label: 'Sticky',
                  isActive: _stickySelection,
                  onPressed: () {
                    setState(() {
                      _stickySelection = !_stickySelection;
                      _game._unitSelectionManager.toggleStickySelection();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Select all units button
                _buildControlButton(
                  icon: Icons.select_all,
                  label: 'All',
                  onPressed: () {
                    _game._unitSelectionManager.selectAllFriendlyUnits();
                  },
                ),
              ],
            ),
          ),
          
          // Ship controls (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Unstick ships button
                _buildControlButton(
                  icon: Icons.anchor,
                  label: 'Unstick',
                  onPressed: () {
                    for (final ship in _game._ships) {
                      if (ship.model.isStuck) {
                        ship.model.unstick();
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ships unstuck'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Selection info panel (bottom left)
          if (_game.selectedUnits.isNotEmpty || _game.selectedShips.isNotEmpty)
            Positioned(
              bottom: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Selected: ${_game.selectedUnits.length} units, ${_game.selectedShips.length} ships',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stop button
                        _buildActionButton(
                          icon: Icons.stop,
                          onPressed: () {
                            // Stop all selected units
                            for (final unit in _game.selectedUnits) {
                              unit.model.targetPosition = unit.model.position.clone();
                              unit.model.targetEnemy = null;
                            }
                            for (final ship in _game.selectedShips) {
                              ship.model.stop();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // Clear selection
                        _buildActionButton(
                          icon: Icons.close,
                          onPressed: () {
                            _game.clearSelection();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          // Zoom controls (bottom right)
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoomIn",
                  onPressed: () {
                    setState(() {
                      _game.zoomIn();
                    });
                  },
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoomOut",
                  onPressed: () {
                    setState(() {
                      _game.zoomOut();
                    });
                  },
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: "zoomReset",
                  onPressed: () {
                    setState(() {
                      _game.resetZoom();
                    });
                  },
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.fit_screen, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive 
                ? Colors.blue.withOpacity(0.7)
                : Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive 
                  ? Colors.blue.shade300
                  : Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper extension
extension OffsetToVector2 on Offset {
  Vector2 toVector2() => Vector2(dx, dy);
}