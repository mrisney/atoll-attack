import 'package:flutter/material.dart';
import 'alpha_shape.dart';
import 'pirate_map_painter.dart';
import 'dart:math';

class PirateMapWidget extends StatelessWidget {
  final List<List<Point2D>> islandData;
  final double width;
  final double height;
  final bool enableInteraction;
  
  const PirateMapWidget({
    Key? key,
    required this.islandData,
    this.width = 800, // Increased default size
    this.height = 800,
    this.enableInteraction = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final mapWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: PirateMapPainter(
            islands: islandData,
            mapSize: Size(width, height),
          ),
          size: Size(width, height),
        ),
      ),
    );

    if (enableInteraction) {
      return InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        constrained: false,
        child: mapWidget,
      );
    } else {
      return mapWidget;
    }
  }
}

// Updated demo with larger map and camera controls
class PirateMapDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Generate sample atoll data with more points for detail
    final random = Random(42);
    List<List<Point2D>> islands = [];
    
    // Main island - larger and more detailed
    List<Point2D> mainIsland = [];
    for (int i = 0; i < 50; i++) { // More points for smoother curves
      double angle = (i * 2 * pi) / 50;
      double radius = 150 + random.nextDouble() * 80; // Larger radius
      mainIsland.add(Point2D(
        400 + radius * cos(angle), // Centered in larger canvas
        400 + radius * sin(angle),
      ));
    }
    islands.add(mainIsland);
    
    // Smaller islands
    for (int i = 0; i < 4; i++) {
      List<Point2D> smallIsland = [];
      double centerX = 200 + random.nextDouble() * 400;
      double centerY = 200 + random.nextDouble() * 400;
      
      for (int j = 0; j < 20; j++) {
        double angle = (j * 2 * pi) / 20;
        double radius = 40 + random.nextDouble() * 30;
        smallIsland.add(Point2D(
          centerX + radius * cos(angle),
          centerY + radius * sin(angle),
        ));
      }
      islands.add(smallIsland);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atoll Wars - Pirate Map'),
        backgroundColor: const Color(0xFF2E5984),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              // You can add zoom controls here if needed
            },
          ),
        ],
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: PirateMapWidget(
            islandData: islands,
            width: 800,  // Larger map
            height: 800,
            enableInteraction: true, // Enable pan/zoom
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: () {
              // Add zoom in functionality
            },
            child: const Icon(Icons.zoom_in),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: () {
              // Add zoom out functionality
            },
            child: const Icon(Icons.zoom_out),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "center",
            onPressed: () {
              // Add center/reset functionality
            },
            child: const Icon(Icons.center_focus_strong),
          ),
        ],
      ),
    );
  }
}