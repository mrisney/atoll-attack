// voronoi_island_demo.dart
import 'package:flutter/material.dart';
import 'voronoi_island_generator.dart';
import 'voronoi_island_painter.dart';

class VoronoiIslandDemo extends StatefulWidget {
  @override
  _VoronoiIslandDemoState createState() => _VoronoiIslandDemoState();
}

class _VoronoiIslandDemoState extends State<VoronoiIslandDemo> {
  VoronoiIslandData? islandData;
  bool isGenerating = false;

  // Display options
  bool showVoronoiCells = false;
  bool showDelaunayTriangles = false;
  bool showElevation = false;
  bool showMoisture = false;

  // Generation parameters
  double islandFactor = 1.1;
  double mountainPeakiness = 0.4;
  int numRivers = 10;

  @override
  void initState() {
    super.initState();
    _generateIsland();
  }

  Future<void> _generateIsland() async {
    setState(() {
      isGenerating = true;
    });

    // Generate in isolate or future to avoid blocking UI
    await Future.delayed(Duration(milliseconds: 100));

    final generator = VoronoiIslandGenerator(
      width: 800,
      height: 800,
      islandFactor: islandFactor,
      mountainPeakiness: mountainPeakiness,
      numRivers: numRivers,
      seed: DateTime.now().millisecondsSinceEpoch,
    );

    final data = generator.generateIsland();

    setState(() {
      islandData = data;
      isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voronoi Island Generator'),
        backgroundColor: const Color(0xFF2E5984),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isGenerating ? null : _generateIsland,
            tooltip: 'Generate New Island',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'Info',
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF2E5984),
        child: Center(
          child: isGenerating
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Generating island...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
              : islandData == null
                  ? Text(
                      'Failed to generate island',
                      style: TextStyle(color: Colors.white),
                    )
                  : InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(100),
                      minScale: 0.3,
                      maxScale: 5.0,
                      child: Container(
                        width: 800,
                        height: 800,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CustomPaint(
                            painter: VoronoiIslandPainter(
                              islandData: islandData!,
                              showVoronoiCells: showVoronoiCells,
                              showDelaunayTriangles: showDelaunayTriangles,
                              showElevation: showElevation,
                              showMoisture: showMoisture,
                            ),
                            size: Size(800, 800),
                          ),
                        ),
                      ),
                    ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "voronoi",
            onPressed: () {
              setState(() {
                showVoronoiCells = !showVoronoiCells;
                if (showVoronoiCells) showDelaunayTriangles = false;
              });
            },
            backgroundColor: showVoronoiCells ? Colors.green : Colors.grey,
            child: const Icon(Icons.grid_on, color: Colors.white),
            tooltip: 'Toggle Voronoi Cells',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "delaunay",
            onPressed: () {
              setState(() {
                showDelaunayTriangles = !showDelaunayTriangles;
                if (showDelaunayTriangles) showVoronoiCells = false;
              });
            },
            backgroundColor: showDelaunayTriangles ? Colors.green : Colors.grey,
            child: const Icon(Icons.change_history, color: Colors.white),
            tooltip: 'Toggle Delaunay Triangles',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "elevation",
            onPressed: () {
              setState(() {
                showElevation = !showElevation;
                if (showElevation) showMoisture = false;
              });
            },
            backgroundColor: showElevation ? Colors.green : Colors.grey,
            child: const Icon(Icons.terrain, color: Colors.white),
            tooltip: 'Show Elevation',
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "moisture",
            onPressed: () {
              setState(() {
                showMoisture = !showMoisture;
                if (showMoisture) showElevation = false;
              });
            },
            backgroundColor: showMoisture ? Colors.green : Colors.grey,
            child: const Icon(Icons.water_drop, color: Colors.white),
            tooltip: 'Show Moisture',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "generate",
            onPressed: isGenerating ? null : _generateIsland,
            backgroundColor: const Color(0xFF4CAF50),
            child: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Generate New Island',
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Island Generation Settings'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Island Size Factor: ${islandFactor.toStringAsFixed(2)}'),
              Slider(
                value: islandFactor,
                min: 0.5,
                max: 2.0,
                onChanged: (value) {
                  setDialogState(() {
                    islandFactor = value;
                  });
                },
              ),
              SizedBox(height: 16),
              Text(
                  'Mountain Peakiness: ${mountainPeakiness.toStringAsFixed(2)}'),
              Slider(
                value: mountainPeakiness,
                min: 0.1,
                max: 1.0,
                onChanged: (value) {
                  setDialogState(() {
                    mountainPeakiness = value;
                  });
                },
              ),
              SizedBox(height: 16),
              Text('Number of Rivers: $numRivers'),
              Slider(
                value: numRivers.toDouble(),
                min: 0,
                max: 30,
                divisions: 30,
                onChanged: (value) {
                  setDialogState(() {
                    numRivers = value.round();
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
              _generateIsland();
            },
            child: Text('Apply & Generate'),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Voronoi Island Generation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This demonstrates Delaunay/Voronoi-based island generation, '
                'similar to the approach used in mapgen4.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Key Features:'),
              Text('• Poisson disc sampling for even point distribution'),
              Text('• Delaunay triangulation with dual mesh structure'),
              Text('• Voronoi regions for natural terrain shapes'),
              Text('• Elevation assignment with noise functions'),
              Text('• Moisture simulation based on distance from water'),
              Text('• Biome assignment based on elevation and moisture'),
              Text('• River generation following elevation gradients'),
              Text('• XKCD-style hand-drawn rendering'),
              SizedBox(height: 16),
              Text('Display Options:'),
              Text('• Grid icon: Show Voronoi cells'),
              Text('• Triangle icon: Show Delaunay triangulation'),
              Text('• Mountain icon: Show elevation map'),
              Text('• Water drop icon: Show moisture map'),
              SizedBox(height: 16),
              Text(
                'Stats for current island:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (islandData != null) ...[
                Text('Regions: ${islandData!.mesh.numSolidRegions}'),
                Text('Triangles: ${islandData!.mesh.numSolidTriangles}'),
                Text('Rivers: ${islandData!.rivers.length}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Main app entry point
class VoronoiIslandApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voronoi Island Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF2E5984),
      ),
      home: VoronoiIslandDemo(),
      debugShowCheckedModeBanner: false,
    );
  }
}
