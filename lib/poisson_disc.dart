// /map_generation/poisson_disc.dart
import 'dart:math' as math;
import 'dual_mesh.dart';

class PoissonDiscSampling {
  final double width;
  final double height;
  final double minDistance;
  final int maxAttempts;
  final math.Random random;

  late double cellSize;
  late int gridWidth;
  late int gridHeight;
  late List<List<int>> grid;
  late List<Point2D> points;
  late List<Point2D> activeList;

  PoissonDiscSampling({
    required this.width,
    required this.height,
    required this.minDistance,
    this.maxAttempts = 30,
    int? seed,
  }) : random = math.Random(seed) {
    cellSize = minDistance / math.sqrt(2);
    gridWidth = (width / cellSize).ceil();
    gridHeight = (height / cellSize).ceil();
    grid = List.generate(gridHeight, (_) => List.filled(gridWidth, -1));
    points = [];
    activeList = [];
  }

  List<Point2D> generate() {
    // Start with a random point
    Point2D firstPoint = Point2D(
      random.nextDouble() * width,
      random.nextDouble() * height,
    );

    _addPoint(firstPoint);

    while (activeList.isNotEmpty) {
      // Pick a random point from the active list
      int randomIndex = random.nextInt(activeList.length);
      Point2D currentPoint = activeList[randomIndex];
      bool foundNewPoint = false;

      // Try to generate new points around it
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        // Generate random point in annulus
        double angle = random.nextDouble() * 2 * math.pi;
        double radius = minDistance * (1 + random.nextDouble());

        Point2D newPoint = Point2D(
          currentPoint.x + radius * math.cos(angle),
          currentPoint.y + radius * math.sin(angle),
        );

        // Check if the point is valid
        if (_isValidPoint(newPoint)) {
          _addPoint(newPoint);
          foundNewPoint = true;
          break;
        }
      }

      // If no new point found, remove from active list
      if (!foundNewPoint) {
        activeList.removeAt(randomIndex);
      }
    }

    return points;
  }

  // Add pre-existing points (like boundary points)
  void addFixedPoints(List<Point2D> fixedPoints) {
    for (Point2D point in fixedPoints) {
      if (_isValidPoint(point)) {
        _addPoint(point);
      }
    }
  }

  bool _isValidPoint(Point2D point) {
    // Check bounds
    if (point.x < 0 || point.x >= width || point.y < 0 || point.y >= height) {
      return false;
    }

    // Check grid neighborhood
    int gridX = (point.x / cellSize).floor();
    int gridY = (point.y / cellSize).floor();

    // Check neighboring cells
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        int nx = gridX + dx;
        int ny = gridY + dy;

        if (nx >= 0 && nx < gridWidth && ny >= 0 && ny < gridHeight) {
          int pointIndex = grid[ny][nx];
          if (pointIndex != -1) {
            Point2D existingPoint = points[pointIndex];
            double distance = point.distanceTo(existingPoint);
            if (distance < minDistance) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  void _addPoint(Point2D point) {
    points.add(point);
    activeList.add(point);

    int gridX = (point.x / cellSize).floor();
    int gridY = (point.y / cellSize).floor();

    if (gridX >= 0 && gridX < gridWidth && gridY >= 0 && gridY < gridHeight) {
      grid[gridY][gridX] = points.length - 1;
    }
  }
}

// Helper for creating islands with good point distribution
class IslandPointGenerator {
  final double width;
  final double height;
  final double spacing;
  final math.Random random;

  IslandPointGenerator({
    required this.width,
    required this.height,
    required this.spacing,
    int? seed,
  }) : random = math.Random(seed);

  List<Point2D> generateIslandPoints({
    double islandFactor = 1.0,
    Point2D? center,
  }) {
    center ??= Point2D(width / 2, height / 2);

    // Generate boundary points
    List<Point2D> boundaryPoints =
        BoundaryGenerator.generateInteriorBoundaryPoints(
      left: 0,
      top: 0,
      width: width,
      height: height,
      boundarySpacing: spacing * math.sqrt(2),
    );

    // Generate interior points with Poisson disc
    PoissonDiscSampling poisson = PoissonDiscSampling(
      width: width,
      height: height,
      minDistance: spacing,
      seed: random.nextInt(1000000),
    );

    poisson.addFixedPoints(boundaryPoints);
    List<Point2D> allPoints = poisson.generate();

    // Filter points to create island shape
    List<Point2D> islandPoints = [];

    for (Point2D p in allPoints) {
      double dx = p.x - center.x;
      double dy = p.y - center.y;
      double distance = math.sqrt(dx * dx + dy * dy);
      double normalizedDistance = distance / (math.min(width, height) / 2);

      // Use noise function for organic shape
      double angle = math.atan2(dy, dx);
      double noiseValue = _noise(angle * 2) * 0.3 +
          _noise(angle * 4) * 0.15 +
          _noise(angle * 8) * 0.05;

      double threshold = islandFactor * (0.7 + noiseValue);

      if (normalizedDistance < threshold) {
        islandPoints.add(p);
      }
    }

    // Ensure we have the boundary points
    islandPoints.insertAll(0, boundaryPoints);

    return islandPoints;
  }

  double _noise(double x) {
    // Simple noise function
    return math.sin(x * 1.0) * 0.5 +
        math.sin(x * 2.3) * 0.3 +
        math.sin(x * 4.7) * 0.2;
  }
}
