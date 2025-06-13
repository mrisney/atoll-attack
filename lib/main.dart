import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart'; // for Vector2
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
  double amplitude = 1.0;
  double wavelength = 0.35;
  double bias = 0.0;
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
      title: 'Noisy Hex Island Generator',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final logicalWidth = constraints.maxWidth;
            final logicalHeight = constraints.maxHeight;
            final logicalSize = Vector2(logicalWidth, logicalHeight);

            // Only create game once or if size changes
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
              );
              lastLogicalSize = logicalSize;
            }

            return Stack(
              children: [
                GameWidget(game: game!),

                // Toggle button for panel
                Positioned(
                  top: 50,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: _togglePanel,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(25),
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

                // Debug info in top left corner
                Positioned(
                  top: 50,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fragment Shader Island',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'A: ${amplitude.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'W: ${wavelength.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'B: ${bias.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'S: $seed',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // Collapsible control panel
                if (_isPanelVisible)
                  AnimatedBuilder(
                    animation: _slideAnimation,
                    builder: (context, child) {
                      return Positioned(
                        left: 10,
                        right: 10,
                        bottom: -250 + (250 * _slideAnimation.value),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(
          color: Colors.blue.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Controls
          _buildSlider('Amplitude', amplitude, 0.0, 2.0, (v) {
            setState(() {
              amplitude = v;
              _updateGame();
            });
          }),
          _buildSlider('Wavelength', wavelength, 0.1, 2.0, (v) {
            setState(() {
              wavelength = v;
              _updateGame();
            });
          }),
          _buildSlider('Bias', bias, -1.0, 1.0, (v) {
            setState(() {
              bias = v;
              _updateGame();
            });
          }),
          const SizedBox(height: 20),

          // Seed controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('Seed: $seed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('New Island'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            seed =
                                DateTime.now().millisecondsSinceEpoch % 100000;
                            _updateGame();
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.shuffle, size: 20),
                        label: const Text('Random'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            final ms = DateTime.now().millisecondsSinceEpoch;
                            amplitude = 0.5 + (ms % 1000) / 1000.0 * 1.5;
                            wavelength = 0.2 + (ms % 1500) / 1500.0 * 1.5;
                            bias = -0.5 + (ms % 2000) / 2000.0;
                            seed = ms % 100000;
                            _updateGame();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.5)),
                ),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue.shade400,
              inactiveTrackColor: Colors.blue.withOpacity(0.3),
              thumbColor: Colors.blue.shade300,
              overlayColor: Colors.blue.withOpacity(0.2),
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
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
