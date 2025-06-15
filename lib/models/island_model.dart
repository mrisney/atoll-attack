import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart'; // for Vector2
import 'package:fast_noise/fast_noise.dart' as fn;

class GridCell {
  final int gridX;
  final int gridY;
  final Offset center;
  final double elevation;
  final int band;
  final bool isLand;

  GridCell({
    required this.gridX,
    required this.gridY,
    required this.center,
    required this.elevation,
    required this.band,
    required this.isLand,
  });
}

class IslandGridModel {
  final double amplitude;
  final double wavelength;
  final double bias;
  final int seed;
  final Size size;
  final double islandRadius;
  final int gridSteps;
  final fn.SimplexNoise noise;

  final Map<String, List<Offset>> contours;
  final List<GridCell> grid;
  final Offset? apex;

  IslandGridModel({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.size,
    required this.islandRadius,
    required this.gridSteps,
    required this.contours,
    required this.grid,
    required this.apex,
  }) : noise = fn.SimplexNoise(seed: seed, frequency: 1.0);

  factory IslandGridModel.generate({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required Size size,
    required double islandRadius,
    int gridSteps = 40,
    required Map<String, List<Offset>> contours,
  }) {
    final List<GridCell> grid = [];
    Offset? apex;
    double maxElevation = -999.0;

    final coastline = contours['coastline'] ?? [];
    final Path coastPath =
        coastline.isNotEmpty ? (Path()..addPolygon(coastline, true)) : Path();

    final double minRes = math.min(size.width, size.height);
    final double radius = size.width * 0.3 * islandRadius;
    final double step = (radius * 2) / gridSteps;
    final double left = size.width / 2 - radius;
    final double top = size.height / 2 - radius;

    final noiseGen = fn.SimplexNoise(seed: seed, frequency: 1.0);

    for (int i = 0; i <= gridSteps; i++) {
      for (int j = 0; j <= gridSteps; j++) {
        final double x = left + i * step;
        final double y = top + j * step;
        final Offset pt = Offset(x, y);

        bool isLand = coastline.isNotEmpty && coastPath.contains(pt);

        double cx = (x - size.width / 2) / (0.5 * minRes);
        double cy = (y - size.height / 2) / (0.5 * minRes);

        double elevation = _getElevationAt(
          Vector2(cx, cy),
          amplitude,
          wavelength,
          bias,
          seed,
          islandRadius,
          noiseGen,
        );
        int band = _getElevationLevel(
          Vector2(cx, cy),
          amplitude,
          wavelength,
          bias,
          seed,
          islandRadius,
          noiseGen,
        );

        if (isLand && elevation > maxElevation) {
          maxElevation = elevation;
          apex = pt;
        }
        grid.add(GridCell(
          gridX: i,
          gridY: j,
          center: pt,
          elevation: elevation,
          band: band,
          isLand: isLand,
        ));
      }
    }

    return IslandGridModel(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      size: size,
      islandRadius: islandRadius,
      gridSteps: gridSteps,
      contours: contours,
      grid: grid,
      apex: apex,
    );
  }

  // Pure Dart versions of the elevation functions
  static double _getElevationAt(
    Vector2 centered,
    double amplitude,
    double wavelength,
    double bias,
    int seed,
    double islandRadius,
    fn.SimplexNoise noise,
  ) {
    double dist = centered.length;
    double fbm(Vector2 x) {
      double v = 0.0;
      double a = 0.5;
      Vector2 shift = Vector2(100, 100);
      double rotSin = math.sin(0.5);
      double rotCos = math.cos(0.5);
      for (int i = 0; i < 5; ++i) {
        v += a * noise.getNoise2(x.x, x.y);
        double nx = rotCos * x.x + rotSin * x.y;
        double ny = -rotSin * x.x + rotCos * x.y;
        x = Vector2(nx, ny) * 2.0 + shift;
        a *= 0.5;
      }
      return v;
    }

    double addPeak(
        Vector2 pos, Vector2 center, double radius, double intensity) {
      double d = (pos - center).length;
      return intensity * math.exp(-math.pow(d / radius, 2.0));
    }

    Vector2 noiseCoord =
        centered / wavelength + Vector2(seed * 0.01, seed * 0.01);
    double noiseValue = fbm(noiseCoord);
    noiseValue = (noiseValue + 1.0) * 0.5;
    noiseValue = noiseValue * amplitude + bias;
    Vector2 peak1 =
        Vector2(0.3 * math.sin(seed + 1.3), 0.25 * math.cos(seed + 2.7));
    Vector2 peak2 =
        Vector2(-0.26 * math.cos(seed + 3.4), 0.12 * math.sin(seed + 5.8));
    Vector2 peak3 =
        Vector2(0.15 * math.sin(seed + 4.1), -0.20 * math.cos(seed + 2.3));
    noiseValue += addPeak(centered, peak1, 0.13, 0.12);
    noiseValue += addPeak(centered, peak2, 0.10, 0.08);
    noiseValue += addPeak(centered, peak3, 0.09, 0.06);
    noiseValue = noiseValue.clamp(0.0, 1.0);
    double falloff = 1.0 - (dist / islandRadius);
    falloff = falloff.clamp(0.0, 1.0);
    noiseValue *= falloff;
    return noiseValue;
  }

  static int _getElevationLevel(
    Vector2 centered,
    double amplitude,
    double wavelength,
    double bias,
    int seed,
    double islandRadius,
    fn.SimplexNoise noise,
  ) {
    double e = _getElevationAt(
        centered, amplitude, wavelength, bias, seed, islandRadius, noise);
    if (e <= 0.18) return 0; // Deep water
    if (e <= 0.32) return 1; // Shallow water
    if (e < 0.50) return 2; // Low land
    if (e < 0.70) return 3; // Mid elevation
    return 4; // High peaks
  }

  // API
  bool isOnLand(Offset pos) {
    final coastline = contours['coastline'] ?? [];
    if (coastline.isEmpty) return false;
    final path = Path()..addPolygon(coastline, true);
    return path.contains(pos);
  }

  double getElevationAt(Offset pos) {
    double minRes = math.min(size.width, size.height);
    double cx = (pos.dx - size.width / 2) / (0.5 * minRes);
    double cy = (pos.dy - size.height / 2) / (0.5 * minRes);
    return _getElevationAt(
      Vector2(cx, cy),
      amplitude,
      wavelength,
      bias,
      seed,
      islandRadius,
      noise,
    );
  }

  double getMovementSpeedMultiplier(Offset pos) {
    double e = getElevationAt(pos);
    if (e <= 0.32) return 0.0; // water
    if (e < 0.39) return 0.9; // sand/lowland
    if (e < 0.54) return 0.8; // lowland
    if (e < 0.7) return 0.6; // upland
    return 0.5; // peak
  }

  // Helper methods for Vector2 conversion
  Vector2 offsetToVector2(Offset offset) {
    return Vector2(offset.dx, offset.dy);
  }

  Vector2 toCentered(Vector2 worldPosition) {
    double minRes = math.min(size.width, size.height);
    double cx = (worldPosition.x - size.width / 2) / (0.5 * minRes);
    double cy = (worldPosition.y - size.height / 2) / (0.5 * minRes);
    return Vector2(cx, cy);
  }

  // Getters
  List<GridCell> getGridCells() => List.unmodifiable(grid);
  Offset? getApex() => apex;
  Map<String, List<Offset>> getContours() => contours;
  List<Offset> getContour(String name) => contours[name] ?? [];
}