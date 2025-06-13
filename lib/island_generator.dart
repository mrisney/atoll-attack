import 'dart:math';
import 'alpha_shape.dart'; // Optional: for concave hull if desired

/// A simple 2D point
class Point2D {
  final double x;
  final double y;

  Point2D(this.x, this.y);
}

/// Different biome types for the island
enum BiomeType {
  ocean,
  beach,
  grassland,
  forest,
  mountain,
  lake,
}

/// Represents a polygonal region with a biome type and base elevation
class BiomeRegion {
  final List<Point2D> polygon;
  final BiomeType type;
  final double elevation;

  BiomeRegion({
    required this.polygon,
    required this.type,
    required this.elevation,
  });
}

/// Aggregated island data: coastline, biomes, rivers, mountains
class IslandData {
  final List<Point2D> coastline;
  final List<BiomeRegion> biomes;
  final List<List<Point2D>> rivers;
  final List<Point2D> mountains;

  IslandData({
    required this.coastline,
    required this.biomes,
    required this.rivers,
    required this.mountains,
  });
}

/// Generates procedural island geometry with biomes and features
class IslandGenerator {
  final Random _rng;

  IslandGenerator({int seed = 42}) : _rng = Random(seed);

  /// Main entry: generate coastline, biomes, rivers, mountains
  IslandData generate(
      {required double centerX,
      required double centerY,
      required double size,
      int numCoastPoints = 100,
      double islandFactor = 1.07}) {
    // Coastline polygon
    var coastline = _generateCoastline(
        centerX, centerY, size, numCoastPoints, islandFactor);
    // Biome regions: beach + grassland + mountain zone
    var biomes = _generateBiomes(coastline, centerX, centerY, size);
    // Rivers (list of polylines)
    var rivers = _generateRivers(centerX, centerY, size);
    // Mountain peaks
    var mountains = _generateMountains(centerX, centerY, size);

    return IslandData(
      coastline: coastline,
      biomes: biomes,
      rivers: rivers,
      mountains: mountains,
    );
  }

  List<Point2D> _generateCoastline(
      double cx, double cy, double size, int numPoints, double islandFactor) {
    final points = <Point2D>[];
    final actual = min(numPoints, 50);

    for (var i = 0; i < actual; i++) {
      var angle = (i * 2 * pi) / actual;

      // Fractal noise pattern
      double noiseVal = 0;
      noiseVal += _noise(cos(angle * 2), sin(angle * 2)) * 0.4;
      noiseVal += _noise(cos(angle * 4) * 2, sin(angle * 4) * 2) * 0.2;
      noiseVal += _noise(cos(angle * 8) * 4, sin(angle * 8) * 4) * 0.1;
      noiseVal += (_rng.nextDouble() - 0.5) * 0.1;

      var radVar = (0.7 + noiseVal * 0.3);
      var r = size * radVar * islandFactor;
      r = r.clamp(size * 0.3, size * 1.5);

      points.add(Point2D(cx + r * cos(angle), cy + r * sin(angle)));
    }

    // Optional smoothing
    return _smooth(points, 2);
  }

  List<BiomeRegion> _generateBiomes(
      List<Point2D> coast, double cx, double cy, double size) {
    final biomes = <BiomeRegion>[];

    // Beach along coastline
    biomes.add(BiomeRegion(
      polygon: coast,
      type: BiomeType.beach,
      elevation: 0.1,
    ));

    // Inner grassland
    var inner = coast.map((p) {
      var dx = p.x - cx;
      var dy = p.y - cy;
      return Point2D(cx + dx * 0.7, cy + dy * 0.7);
    }).toList();
    inner = _smooth(inner, 1);
    biomes.add(BiomeRegion(
      polygon: inner,
      type: BiomeType.grassland,
      elevation: 0.3,
    ));

    // Mountain ring
    var mountainPoly = coast.mapIndexed((i, p) {
      var dx = p.x - cx;
      var dy = p.y - cy;
      var base = 0.4;
      // jitter
      var ox = _noise(i * 0.1, 0) * size * 0.1;
      var oy = _noise(0, i * 0.1) * size * 0.1;
      return Point2D(
        cx + dx * base + ox,
        cy + dy * base + oy,
      );
    }).toList();
    biomes.add(BiomeRegion(
      polygon: mountainPoly,
      type: BiomeType.mountain,
      elevation: 0.7,
    ));

    return biomes;
  }

  List<List<Point2D>> _generateRivers(double cx, double cy, double size) {
    final rivers = <List<Point2D>>[];
    var count = 2 + _rng.nextInt(2);
    for (var i = 0; i < count; i++) {
      var angle = _rng.nextDouble() * 2 * pi;
      final path = <Point2D>[];
      for (var t = 0.2; t < 0.9; t += 0.1) {
        var dist = size * t;
        var curve = sin(t * pi * 2) * size * 0.1;
        path.add(Point2D(
          cx + dist * cos(angle) + curve * cos(angle + pi / 2),
          cy + dist * sin(angle) + curve * sin(angle + pi / 2),
        ));
      }
      rivers.add(path);
    }
    return rivers;
  }

  List<Point2D> _generateMountains(double cx, double cy, double size) {
    final peaks = <Point2D>[];
    var count = 3 + _rng.nextInt(3);
    for (var i = 0; i < count; i++) {
      var angle = _rng.nextDouble() * 2 * pi;
      var dist = size * (0.1 + _rng.nextDouble() * 0.3);
      peaks.add(Point2D(cx + dist * cos(angle), cy + dist * sin(angle)));
    }
    return peaks;
  }

  /// Smooth a closed polygon by iteratively averaging neighbors
  List<Point2D> _smooth(List<Point2D> pts, int iters) {
    for (var k = 0; k < iters; k++) {
      var sm = <Point2D>[];
      for (var i = 0; i < pts.length; i++) {
        var prev = pts[(i - 1 + pts.length) % pts.length];
        var cur = pts[i];
        var next = pts[(i + 1) % pts.length];
        sm.add(Point2D(
          (prev.x + cur.x * 2 + next.x) / 4,
          (prev.y + cur.y * 2 + next.y) / 4,
        ));
      }
      pts = sm;
    }
    return pts;
  }

  /// 2D Perlin-like noise
  double _noise(double x, double y) {
    var xi = x.floor();
    var yi = y.floor();
    var xf = x - xi;
    var yf = y - yi;
    var u = _fade(xf);
    var v = _fade(yf);
    var a = _hash(xi, yi);
    var b = _hash(xi + 1, yi);
    var c = _hash(xi, yi + 1);
    var d = _hash(xi + 1, yi + 1);
    var x1 = _lerp(a, b, u);
    var x2 = _lerp(c, d, u);
    return _lerp(x1, x2, v);
  }

  double _fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
  double _lerp(double a, double b, double t) => a + t * (b - a);

  double _hash(int x, int y) {
    var n = x + y * 57;
    n = (n << 13) ^ n;
    return 1.0 -
        ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) /
            1073741824.0;
  }
}

// Extension utility for indexed map
extension _IndexedList<E> on List<E> {
  List<T> mapIndexed<T>(T Function(int, E) f) {
    var out = <T>[];
    for (var i = 0; i < length; i++) {
      out.add(f(i, this[i]));
    }
    return out;
  }
}
