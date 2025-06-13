import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'island_game.dart';

void main() {
  runApp(const IslandApp());
}

class IslandApp extends StatefulWidget {
  const IslandApp({Key? key}) : super(key: key);

  @override
  _IslandAppState createState() => _IslandAppState();
}

class _IslandAppState extends State<IslandApp>
    with SingleTickerProviderStateMixin {
  // Updated defaults for visually appealing islands
  double amplitude = 1.6;
  double wavelength = 0.25;
  double bias = -0.7;
  double islandRadius = 0.8;
  int seed = 42;

  bool _isPanelVisible = true;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  IslandGame? game;
  Vector2? lastLogicalSize;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _updateGame() {
    game?.updateParameters(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      islandRadius: islandRadius,
    );
  }

  void _togglePanel() {
    setState(() {
      _isPanelVisible = !_isPanelVisible;
      if (_isPanelVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Island Generator',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final logicalWidth = constraints.maxWidth;
            final logicalHeight = constraints.maxHeight;
            final logicalSize = Vector2(logicalWidth, logicalHeight);

            if (game == null ||
                lastLogicalSize == null ||
                lastLogicalSize!.x != logicalWidth ||
                lastLogicalSize!.y != logicalHeight) {
              game = IslandGame(
                amplitude: amplitude,
                wavelength: wavelength,
                bias: bias,
                seed: seed,
                gameSize: logicalSize,
                islandRadius: islandRadius,
              );
              lastLogicalSize = logicalSize;
            }

            return Stack(
              children: [
                GameWidget(game: game!),

                // Toggle button for panel
                Positioned(
                  top: 30,
                  right: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _togglePanel,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(22),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Icon(
                          _isPanelVisible ? Icons.close : Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                // Collapsible control panel (smaller, bottom-centered)
                if (_isPanelVisible)
                  AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: 24,
                        right: 24,
                        bottom: -180 + (180 * _slideAnimation.value),
                        child: _buildControlPanel(),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.96),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border.all(
          color: Colors.blue.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel handle
          Container(
            width: 32,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildSlider('Amplitude', amplitude, 1.0, 2.0, (v) {
            setState(() {
              amplitude = v;
              _updateGame();
            });
          }),
          _buildSlider('Wavelength', wavelength, 0.15, 0.7, (v) {
            setState(() {
              wavelength = v;
              _updateGame();
            });
          }),
          _buildSlider('Bias', bias, -1.0, 0.2, (v) {
            setState(() {
              bias = v;
              _updateGame();
            });
          }),
          _buildSlider('Island Size', islandRadius, 0.4, 1.2, (v) {
            setState(() {
              islandRadius = v;
              _updateGame();
            });
          }),
          const SizedBox(height: 10),

          // Seed controls (in a more compact layout)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seed: $seed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        seed = DateTime.now().millisecondsSinceEpoch % 100000;
                        _updateGame();
                      });
                    },
                    child: const Icon(Icons.refresh, size: 18),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      setState(() {
                        final ms = DateTime.now().millisecondsSinceEpoch;
                        amplitude = 1.0 + (ms % 1000) / 1000.0 * 1.0;
                        wavelength = 0.15 + (ms % 700) / 700.0 * 0.55;
                        bias = -1.0 + (ms % 1200) / 1200.0 * 1.2;
                        islandRadius = 0.5 + (ms % 700) / 700.0 * 0.7;
                        seed = ms % 100000;
                        _updateGame();
                      });
                    },
                    child: const Icon(Icons.shuffle, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.blue.withOpacity(0.38)),
                ),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue.shade400,
              inactiveTrackColor: Colors.blue.withOpacity(0.22),
              thumbColor: Colors.blue.shade300,
              overlayColor: Colors.blue.withOpacity(0.13),
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
