// advanced_pirate_map.dart
import 'package:flutter/material.dart';
import 'pirate_map_widget.dart';
import 'alpha_shape.dart';
import 'island_generator.dart';
import 'dart:math';

class AdvancedPirateMapDemo extends StatefulWidget {
  @override
  _AdvancedPirateMapDemoState createState() => _AdvancedPirateMapDemoState();
}

class _AdvancedPirateMapDemoState extends State<AdvancedPirateMapDemo> {
  final TransformationController _transformationController =
      TransformationController();
  late List<IslandData> islandDataList;
  late List<List<Point2D>> islands; // For compatibility with existing painter

  @override
  void initState() {
    super.initState();
    _generateRealisticIslands();
  }

  void _generateRealisticIslands() {
    final generator = IslandGenerator(seed: 42);
    islandDataList = [];
    islands = [];

    // Generate main island
    IslandData mainIsland = generator.generateIsland(
      centerX: 500,
      centerY: 500,
      size: 300,
      numPoints: 800,
      islandFactor: 1.1,
    );
    islandDataList.add(mainIsland);
    islands.add(mainIsland.coastline);

    // Generate smaller islands
    final random = Random(42);
    for (int i = 0; i < 4; i++) {
      double centerX = 200 + random.nextDouble() * 600;
      double centerY = 200 + random.nextDouble() * 600;

      // Avoid overlapping with main island
      if (Point2D(centerX, centerY).distanceTo(Point2D(500, 500)) > 200) {
        IslandData smallIsland = generator.generateIsland(
          centerX: centerX,
          centerY: centerY,
          size: 80 + random.nextDouble() * 60,
          numPoints: 200,
          islandFactor: 1.0 + random.nextDouble() * 0.2,
        );
        islandDataList.add(smallIsland);
        islands.add(smallIsland.coastline);
      }
    }
  }

  void _zoomIn() {
    setState(() {
      Matrix4 current = _transformationController.value;
      double currentScale = current.getMaxScaleOnAxis();
      if (currentScale < 5.0) {
        _transformationController.value = Matrix4.identity()
          ..scale(currentScale * 1.2);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      Matrix4 current = _transformationController.value;
      double currentScale = current.getMaxScaleOnAxis();
      if (currentScale > 0.3) {
        _transformationController.value = Matrix4.identity()
          ..scale(currentScale * 0.8);
      }
    });
  }

  void _resetCamera() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _regenerateIslands() {
    setState(() {
      // Use different seed for variety
      final newSeed = DateTime.now().millisecondsSinceEpoch % 10000;
      final generator = IslandGenerator(seed: newSeed);
      islandDataList = [];
      islands = [];

      // Generate main island with random parameters
      final random = Random(newSeed);
      IslandData mainIsland = generator.generateIsland(
        centerX: 500,
        centerY: 500,
        size: 250 + random.nextDouble() * 100,
        numPoints: 600 + random.nextInt(400),
        islandFactor: 1.0 + random.nextDouble() * 0.3,
      );
      islandDataList.add(mainIsland);
      islands.add(mainIsland.coastline);

      // Generate smaller islands
      int numSmallIslands = 3 + random.nextInt(4);
      for (int i = 0; i < numSmallIslands; i++) {
        double centerX = 150 + random.nextDouble() * 700;
        double centerY = 150 + random.nextDouble() * 700;

        // Avoid overlapping with main island
        if (Point2D(centerX, centerY).distanceTo(Point2D(500, 500)) > 180) {
          IslandData smallIsland = generator.generateIsland(
            centerX: centerX,
            centerY: centerY,
            size: 60 + random.nextDouble() * 80,
            numPoints: 150 + random.nextInt(100),
            islandFactor: 0.9 + random.nextDouble() * 0.4,
          );
          islandDataList.add(smallIsland);
          islands.add(smallIsland.coastline);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atoll Wars - Realistic Islands'),
        backgroundColor: const Color(0xFF2E5984),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _regenerateIslands,
            tooltip: 'Generate New Islands',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showIslandInfo();
            },
            tooltip: 'Island Info',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF2E5984),
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(50),
          minScale: 0.3,
          maxScale: 5.0,
          constrained: false,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: PirateMapWidget(
              islandData: islands,
              width: 1000,
              height: 1000,
              enableInteraction: false, // Handled by outer InteractiveViewer
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "info",
            onPressed: _showIslandInfo,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.info, color: Colors.white),
            tooltip: 'Island Statistics',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "refresh",
            onPressed: _regenerateIslands,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Generate New Islands',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: _zoomIn,
            backgroundColor: const Color(0xFF2E5984),
            child: const Icon(Icons.zoom_in, color: Colors.white),
            tooltip: 'Zoom In',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: _zoomOut,
            backgroundColor: const Color(0xFF2E5984),
            child: const Icon(Icons.zoom_out, color: Colors.white),
            tooltip: 'Zoom Out',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "center",
            onPressed: _resetCamera,
            backgroundColor: const Color(0xFF2E5984),
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
            tooltip: 'Reset View',
          ),
        ],
      ),
    );
  }

  void _showIslandInfo() {
    int totalCoastlinePoints = 0;
    int totalRivers = 0;
    int totalMountains = 0;
    int totalBiomes = 0;

    for (IslandData island in islandDataList) {
      totalCoastlinePoints += island.coastline.length;
      totalRivers += island.rivers.length;
      totalMountains += island.mountains.length;
      totalBiomes += island.biomes.length;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Island Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number of Islands: ${islandDataList.length}'),
              const SizedBox(height: 8),
              Text('Total Coastline Points: $totalCoastlinePoints'),
              Text('Total Rivers: $totalRivers'),
              Text('Total Mountains: $totalMountains'),
              Text('Total Biome Regions: $totalBiomes'),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Voronoi-based terrain generation'),
              const Text('• Realistic coastlines with elevation'),
              const Text('• Multiple biomes (beach, forest, mountains)'),
              const Text('• Rivers flowing from peaks to ocean'),
              const Text('• Procedural island shapes'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('New Islands'),
              onPressed: () {
                Navigator.of(context).pop();
                _regenerateIslands();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}
