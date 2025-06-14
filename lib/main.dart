import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'island_game.dart';
import 'island_settings_panel.dart';
import 'game_controls_panel.dart';

void main() {
  runApp(const IslandApp());
}

class IslandApp extends StatefulWidget {
  const IslandApp({Key? key}) : super(key: key);

  @override
  State<IslandApp> createState() => _IslandAppState();
}

class _IslandAppState extends State<IslandApp> {
  // Island generation settings
  double amplitude = 1.6;
  double wavelength = 0.25;
  double bias = -0.7;
  double islandRadius = 0.8;
  int seed = 42;
  bool showPerimeter = false;

  // Panel visibility
  bool showIslandSettings = false;
  bool showGameControls = false;

  IslandGame? game;
  Vector2? lastLogicalSize;

  void _updateGame() {
    game?.updateParameters(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      islandRadius: islandRadius,
    );
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
                showPerimeter: showPerimeter,
              );
              lastLogicalSize = logicalSize;
            } else {
              game!.showPerimeter = showPerimeter;
            }

            return Stack(
              children: [
                GameWidget(game: game!),

                // Main top-right menu: open settings or game controls
                Positioned(
                  top: 30,
                  right: 16,
                  child: Column(
                    children: [
                      // Island Settings button
                      FloatingActionButton(
                        heroTag: "islandSettingsBtn",
                        mini: true,
                        backgroundColor: Colors.blueGrey,
                        child: const Icon(Icons.settings),
                        onPressed: () {
                          setState(() {
                            showIslandSettings = !showIslandSettings;
                            if (showIslandSettings) showGameControls = false;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // Game Controls button
                      FloatingActionButton(
                        heroTag: "gameControlsBtn",
                        mini: true,
                        backgroundColor: Colors.orange,
                        child: const Icon(Icons.sports_esports),
                        onPressed: () {
                          setState(() {
                            showGameControls = !showGameControls;
                            if (showGameControls) showIslandSettings = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Island Settings Panel
                if (showIslandSettings)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 0,
                    child: IslandSettingsPanel(
                      amplitude: amplitude,
                      wavelength: wavelength,
                      bias: bias,
                      islandRadius: islandRadius,
                      seed: seed,
                      onAmplitudeChanged: (v) => setState(() {
                        amplitude = v;
                        _updateGame();
                      }),
                      onWavelengthChanged: (v) => setState(() {
                        wavelength = v;
                        _updateGame();
                      }),
                      onBiasChanged: (v) => setState(() {
                        bias = v;
                        _updateGame();
                      }),
                      onIslandRadiusChanged: (v) => setState(() {
                        islandRadius = v;
                        _updateGame();
                      }),
                      onSeedChanged: (v) => setState(() {
                        seed = v;
                        _updateGame();
                      }),
                      onRandomize: () {
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
                      onClose: () => setState(() => showIslandSettings = false),
                    ),
                  ),

                // Game Controls Panel
                if (showGameControls)
                  Positioned(
                    right: 12,
                    bottom: 24,
                    child: GameControlsPanel(
                      showPerimeter: showPerimeter,
                      onTogglePerimeter: (v) => setState(() {
                        showPerimeter = v;
                        game?.showPerimeter = v;
                      }),
                      onSpawnUnits: () => game?.spawnUnits(12),
                      onClose: () => setState(() => showGameControls = false),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
