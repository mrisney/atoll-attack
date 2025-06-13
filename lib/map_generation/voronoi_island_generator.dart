// voronoi_island_generator.dart
import 'dart:math' as math;
import 'dart:collection';
import 'package:flutter/material.dart';
import 'dual_mesh.dart';
import 'delaunay.dart';
import 'poisson_disc.dart';

class VoronoiIslandData {
  final TriangleMesh mesh;
  final VoronoiDiagram voronoi;
  final Map<int, double> regionElevation;
  final Map<int, BiomeType> regionBiome;
  final Map<int, double> regionMoisture;
  final List<River> rivers;
  final List<Path> coastlines;

  VoronoiIslandData({
    required this.mesh,
    required this.voronoi,
    required this.regionElevation,
    required this.regionBiome,
    required this.regionMoisture,
    required this.rivers,
    required this.coastlines,
  });
}

class River {
  final List<Point2D> path;
  final double flow;

  River({required this.path, required this.flow});
}

enum BiomeType {
  ocean,
  lake,
  beach,
  grassland,
  forest,
  rainforest,
  desert,
  tundra,
  mountain,
  snow,
}

class VoronoiIslandGenerator {
  final double width;
  final double height;
  final math.Random random;

  // Generation parameters
  final double islandFactor;
  final double mountainPeakiness;
  final int numRivers;

  VoronoiIslandGenerator({
    required this.width,
    required this.height,
    this.islandFactor = 1.1,
    this.mountainPeakiness = 0.4,
    this.numRivers = 10,
    int? seed,
  }) : random = math.Random(seed);

  VoronoiIslandData generateIsland() {
    // Step 1: Generate points
    print("Generating points...");
    final points = _generatePoints();

    // Step 2: Create Delaunay triangulation
    print("Creating Delaunay triangulation...");
    final delaunay = DelaunayTriangulation(points);
    final delaunatorResult = delaunay.toDelaunatorResult();

    // Step 3: Create dual mesh with ghost structure
    print("Creating dual mesh...");
    var meshInit = MeshInitializer(
      points: points,
      delaunator: delaunatorResult,
      numBoundaryPoints: _calculateBoundaryPoints(points),
      numSolidSides: delaunatorResult.triangles.length,
    );

    meshInit = TriangleMesh.addGhostStructure(meshInit);
    final mesh = TriangleMesh.fromDelaunator(
      points: meshInit.points,
      delaunator: meshInit.delaunator,
      numBoundaryPoints: meshInit.numBoundaryPoints,
      numSolidSides: meshInit.numSolidSides,
    );

    // Step 4: Generate Voronoi diagram
    print("Generating Voronoi diagram...");
    final voronoi = VoronoiDiagram(mesh);

    // Step 5: Assign elevations
    print("Assigning elevations...");
    final regionElevation = _assignElevations(mesh);

    // Step 6: Assign moisture
    print("Assigning moisture...");
    final regionMoisture = _assignMoisture(mesh, regionElevation);

    // Step 7: Assign biomes
    print("Assigning biomes...");
    final regionBiome = _assignBiomes(mesh, regionElevation, regionMoisture);

    // Step 8: Generate rivers
    print("Generating rivers...");
    final rivers = _generateRivers(mesh, regionElevation);

    // Step 9: Generate coastlines
    print("Generating coastlines...");
    final coastlines = _generateCoastlines(mesh, regionElevation, voronoi);

    return VoronoiIslandData(
      mesh: mesh,
      voronoi: voronoi,
      regionElevation: regionElevation,
      regionBiome: regionBiome,
      regionMoisture: regionMoisture,
      rivers: rivers,
      coastlines: coastlines,
    );
  }

  List<Point2D> _generatePoints() {
    // Use boundary points + Poisson disc sampling
    final spacing = math.min(width, height) / 50;

    // Generate boundary points
    List<Point2D> boundaryPoints =
        BoundaryGenerator.generateInteriorBoundaryPoints(
      left: spacing,
      top: spacing,
      width: width - 2 * spacing,
      height: height - 2 * spacing,
      boundarySpacing: spacing * math.sqrt(2),
    );

    // Generate interior points
    final poisson = PoissonDiscSampling(
      width: width,
      height: height,
      minDistance: spacing,
      seed: random.nextInt(1000000),
    );

    poisson.addFixedPoints(boundaryPoints);
    final allPoints = poisson.generate();

    return allPoints;
  }

  int _calculateBoundaryPoints(List<Point2D> points) {
    // Points near the edge are boundary points
    int count = 0;
    final margin = math.min(width, height) * 0.05;

    for (final p in points) {
      if (p.x < margin ||
          p.x > width - margin ||
          p.y < margin ||
          p.y > height - margin) {
        count++;
      }
    }

    return count;
  }

  Map<int, double> _assignElevations(TriangleMesh mesh) {
    Map<int, double> elevation = {};
    final center = Point2D(width / 2, height / 2);

    // Initialize all regions
    for (int r = 0; r < mesh.numRegions; r++) {
      if (mesh.is_ghost_r(r)) {
        elevation[r] = -1;
        continue;
      }

      Point2D pos = mesh.pos_of_r(r);
      double distance = pos.distanceTo(center) / (math.min(width, height) / 2);

      // Use multiple noise frequencies for natural elevation
      double e = 1 - distance;
      e += _noise2D(pos.x * 0.01, pos.y * 0.01) * 0.3;
      e += _noise2D(pos.x * 0.02, pos.y * 0.02) * 0.2;
      e += _noise2D(pos.x * 0.04, pos.y * 0.04) * 0.1;

      // Apply island factor
      e = math.pow(e * islandFactor, mountainPeakiness).toDouble();

      // Clamp and apply threshold
      e = e.clamp(0.0, 1.0);
      if (e < 0.3) e = 0; // Create distinct ocean

      elevation[r] = e;
    }

    // Smooth elevations
    for (int i = 0; i < 3; i++) {
      elevation = _smoothElevations(mesh, elevation);
    }

    return elevation;
  }

  Map<int, double> _smoothElevations(
      TriangleMesh mesh, Map<int, double> elevation) {
    Map<int, double> smoothed = {};

    for (int r = 0; r < mesh.numRegions; r++) {
      if (mesh.is_ghost_r(r)) {
        smoothed[r] = elevation[r]!;
        continue;
      }

      double sum = elevation[r]! * 3; // Weight center more
      int count = 3;

      for (int neighbor in mesh.r_around_r(r)) {
        if (!mesh.is_ghost_r(neighbor)) {
          sum += elevation[neighbor]!;
          count++;
        }
      }

      smoothed[r] = sum / count;
    }

    return smoothed;
  }

  Map<int, double> _assignMoisture(
      TriangleMesh mesh, Map<int, double> elevation) {
    Map<int, double> moisture = {};

    // Initialize moisture based on distance from water
    Queue<int> queue = Queue();
    Set<int> visited = {};

    // Start from all water regions
    for (int r = 0; r < mesh.numRegions; r++) {
      if (elevation[r]! <= 0) {
        moisture[r] = 1.0;
        queue.add(r);
        visited.add(r);
      } else {
        moisture[r] = 0.0;
      }
    }

    // Propagate moisture inland
    while (queue.isNotEmpty) {
      int r = queue.removeFirst();
      double currentMoisture = moisture[r]!;

      for (int neighbor in mesh.r_around_r(r)) {
        if (!visited.contains(neighbor) && !mesh.is_ghost_r(neighbor)) {
          visited.add(neighbor);

          // Decrease moisture with distance and elevation
          double elevDiff = math.max(0, elevation[neighbor]! - elevation[r]!);
          moisture[neighbor] = currentMoisture * (0.9 - elevDiff * 0.5);

          if (moisture[neighbor]! > 0.01) {
            queue.add(neighbor);
          }
        }
      }
    }

    // Add some noise for variation
    for (int r = 0; r < mesh.numRegions; r++) {
      if (elevation[r]! > 0) {
        Point2D pos = mesh.pos_of_r(r);
        moisture[r] =
            (moisture[r]! + _noise2D(pos.x * 0.03, pos.y * 0.03) * 0.3)
                .clamp(0.0, 1.0);
      }
    }

    return moisture;
  }

  Map<int, BiomeType> _assignBiomes(
    TriangleMesh mesh,
    Map<int, double> elevation,
    Map<int, double> moisture,
  ) {
    Map<int, BiomeType> biomes = {};

    for (int r = 0; r < mesh.numRegions; r++) {
      double e = elevation[r]!;
      double m = moisture[r]!;

      if (e <= 0) {
        biomes[r] = BiomeType.ocean;
      } else if (e < 0.1) {
        biomes[r] = BiomeType.beach;
      } else if (e > 0.8) {
        if (e > 0.9) {
          biomes[r] = BiomeType.snow;
        } else {
          biomes[r] = BiomeType.mountain;
        }
      } else {
        // Lowland biomes based on moisture
        if (m < 0.2) {
          biomes[r] = BiomeType.desert;
        } else if (m < 0.5) {
          biomes[r] = BiomeType.grassland;
        } else if (m < 0.8) {
          biomes[r] = BiomeType.forest;
        } else {
          biomes[r] = BiomeType.rainforest;
        }
      }
    }

    return biomes;
  }

  List<River> _generateRivers(TriangleMesh mesh, Map<int, double> elevation) {
    List<River> rivers = [];

    // Find potential river sources (high elevation regions)
    List<int> sources = [];
    for (int r = 0; r < mesh.numRegions; r++) {
      if (elevation[r]! > 0.7 && elevation[r]! < 0.9) {
        sources.add(r);
      }
    }

    // Shuffle and select some sources
    sources.shuffle(random);
    int riverCount = math.min(numRivers, sources.length);

    for (int i = 0; i < riverCount; i++) {
      River? river = _traceRiver(mesh, elevation, sources[i]);
      if (river != null && river.path.length > 5) {
        rivers.add(river);
      }
    }

    return rivers;
  }

  River? _traceRiver(
      TriangleMesh mesh, Map<int, double> elevation, int source) {
    List<Point2D> path = [];
    Set<int> visited = {};
    int current = source;
    double flow = 1.0;

    while (elevation[current]! > 0 && !visited.contains(current)) {
      visited.add(current);
      path.add(mesh.pos_of_r(current));

      // Find lowest neighbor
      int? lowestNeighbor;
      double lowestElevation = elevation[current]!;

      for (int neighbor in mesh.r_around_r(current)) {
        if (!mesh.is_ghost_r(neighbor) &&
            !visited.contains(neighbor) &&
            elevation[neighbor]! < lowestElevation) {
          lowestElevation = elevation[neighbor]!;
          lowestNeighbor = neighbor;
        }
      }

      if (lowestNeighbor == null) break;

      current = lowestNeighbor;
      flow += 0.1;
    }

    if (path.length < 3) return null;

    return River(path: path, flow: flow);
  }

  List<Path> _generateCoastlines(
    TriangleMesh mesh,
    Map<int, double> elevation,
    VoronoiDiagram voronoi,
  ) {
    List<Path> coastlines = [];
    Set<String> processedEdges = {};

    // Find all edges between land and water
    for (int r = 0; r < mesh.numSolidRegions; r++) {
      if (elevation[r]! <= 0) continue; // Skip water regions

      List<int> neighbors = mesh.r_around_r(r);
      for (int i = 0; i < neighbors.length; i++) {
        int neighbor = neighbors[i];

        if (elevation[neighbor]! > 0) continue; // Skip if both are land

        // Create edge key
        String edgeKey = '${math.min(r, neighbor)}-${math.max(r, neighbor)}';
        if (processedEdges.contains(edgeKey)) continue;
        processedEdges.add(edgeKey);

        // Find the shared edge vertices
        Path coastSegment = Path();

        // Get the triangles that share this edge
        List<int> sides = mesh.s_around_r(r);
        for (int s in sides) {
          if (mesh.r_end_s(s) == neighbor || mesh.r_begin_s(s) == neighbor) {
            // This side connects r and neighbor
            int t1 = mesh.t_inner_s(s);
            int t2 = mesh.t_outer_s(s);

            if (!mesh.is_ghost_t(t1) && !mesh.is_ghost_t(t2)) {
              Point2D p1 = voronoi.circumcenters[t1];
              Point2D p2 = voronoi.circumcenters[t2];

              if (coastSegment.getBounds().isEmpty) {
                coastSegment.moveTo(p1.x, p1.y);
              }
              coastSegment.lineTo(p2.x, p2.y);
            }
          }
        }

        if (!coastSegment.getBounds().isEmpty) {
          coastlines.add(coastSegment);
        }
      }
    }

    return coastlines;
  }

  // Simple 2D noise function
  double _noise2D(double x, double y) {
    int xi = x.floor();
    int yi = y.floor();
    double xf = x - xi;
    double yf = y - yi;

    // Interpolate
    double a = _randomValue(xi, yi);
    double b = _randomValue(xi + 1, yi);
    double c = _randomValue(xi, yi + 1);
    double d = _randomValue(xi + 1, yi + 1);

    double u = xf * xf * (3.0 - 2.0 * xf);
    double v = yf * yf * (3.0 - 2.0 * yf);

    return a * (1 - u) * (1 - v) +
        b * u * (1 - v) +
        c * (1 - u) * v +
        d * u * v;
  }

  double _randomValue(int x, int y) {
    int n = x + y * 57;
    n = (n << 13) ^ n;
    return (1.0 -
        ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
            1073741824.0);
  }
}

// Add missing Queue import
class Queue<T> {
  final List<T> _list = [];

  void add(T item) => _list.add(item);
  T removeFirst() => _list.removeAt(0);
  bool get isEmpty => _list.isEmpty;
  bool get isNotEmpty => _list.isNotEmpty;
}
