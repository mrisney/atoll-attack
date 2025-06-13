// voronoi_island_painter.dart
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'voronoi_island_generator.dart';
import 'dual_mesh.dart';

class VoronoiIslandPainter extends CustomPainter {
  final VoronoiIslandData islandData;
  final bool showVoronoiCells;
  final bool showDelaunayTriangles;
  final bool showElevation;
  final bool showMoisture;

  // XKCD color palette
  static const waterColor = Color(0xFF2185C5);
  static const shallowWaterColor = Color(0xFF4FA9E1);
  static const sandColor = Color(0xFFFFFFA6);
  static const grassColor = Color(0xFFBDF271);
  static const darkSandColor = Color(0xFFCFC291);
  static const forestColor = Color(0xFF4A7C5B);
  static const mountainColor = Color(0xFF8B7355);
  static const snowColor = Color(0xFFFFFFFF);
  static const desertColor = Color(0xFFE4C4A1);
  static const pathColor = Color(0xFFDC3522);

  static const biomeColors = {
    BiomeType.ocean: waterColor,
    BiomeType.lake: waterColor,
    BiomeType.beach: sandColor,
    BiomeType.grassland: grassColor,
    BiomeType.forest: forestColor,
    BiomeType.rainforest: Color(0xFF2B5F2B),
    BiomeType.desert: desertColor,
    BiomeType.tundra: Color(0xFFDDDDBB),
    BiomeType.mountain: mountainColor,
    BiomeType.snow: snowColor,
  };

  VoronoiIslandPainter({
    required this.islandData,
    this.showVoronoiCells = false,
    this.showDelaunayTriangles = false,
    this.showElevation = false,
    this.showMoisture = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw ocean background
    _drawOceanBackground(canvas, size);

    if (showDelaunayTriangles) {
      _drawDelaunayTriangles(canvas);
    }

    if (showVoronoiCells) {
      _drawVoronoiCells(canvas);
    } else {
      // Draw the island using regions
      _drawIslandRegions(canvas);
    }

    // Draw rivers
    _drawRivers(canvas);

    // Draw coastline
    _drawCoastlines(canvas);

    // Draw decorations
    _drawCompass(canvas, size);
  }

  void _drawOceanBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Add wave pattern
    _drawWavePattern(canvas, size);
  }

  void _drawWavePattern(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 30; i++) {
      final y = i * 30.0;
      final wavePath = Path();
      wavePath.moveTo(0, y);

      for (double x = 0; x < size.width; x += 20) {
        final waveY = y + math.sin(x * 0.02 + i) * 8;
        wavePath.lineTo(x, waveY);
      }

      canvas.drawPath(wavePath, paint);
    }
  }

  void _drawDelaunayTriangles(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black.withOpacity(0.3);

    final mesh = islandData.mesh;

    for (int t = 0; t < mesh.numSolidTriangles; t++) {
      List<int> vertices = mesh.r_around_t(t);

      final path = Path();
      path.moveTo(mesh.x_of_r(vertices[0]), mesh.y_of_r(vertices[0]));
      path.lineTo(mesh.x_of_r(vertices[1]), mesh.y_of_r(vertices[1]));
      path.lineTo(mesh.x_of_r(vertices[2]), mesh.y_of_r(vertices[2]));
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawVoronoiCells(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.black.withOpacity(0.5);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < islandData.mesh.numSolidRegions; r++) {
      if (islandData.voronoi.regions[r].isEmpty) continue;

      final region = islandData.voronoi.regions[r];
      final path = Path();

      if (region.isNotEmpty) {
        path.moveTo(region[0].x, region[0].y);
        for (int i = 1; i < region.length; i++) {
          path.lineTo(region[i].x, region[i].y);
        }
        path.close();

        // Fill with appropriate color
        if (showElevation) {
          double elevation = islandData.regionElevation[r]!;
          fillPaint.color = _getElevationColor(elevation);
        } else if (showMoisture) {
          double moisture = islandData.regionMoisture[r]!;
          fillPaint.color = _getMoistureColor(moisture);
        } else {
          fillPaint.color = biomeColors[islandData.regionBiome[r]]!;
        }

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawIslandRegions(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Group regions by biome for better rendering
    Map<BiomeType, List<Path>> biomeRegions = {};

    for (int r = 0; r < islandData.mesh.numSolidRegions; r++) {
      if (islandData.voronoi.regions[r].isEmpty) continue;

      final biome = islandData.regionBiome[r]!;
      final region = islandData.voronoi.regions[r];

      if (region.isNotEmpty) {
        final path = Path();
        path.moveTo(region[0].x, region[0].y);

        for (int i = 1; i < region.length; i++) {
          path.lineTo(region[i].x, region[i].y);
        }
        path.close();

        biomeRegions.putIfAbsent(biome, () => []).add(path);
      }
    }

    // Draw biomes in order
    final biomeOrder = [
      BiomeType.ocean,
      BiomeType.beach,
      BiomeType.desert,
      BiomeType.grassland,
      BiomeType.forest,
      BiomeType.rainforest,
      BiomeType.mountain,
      BiomeType.snow,
    ];

    for (final biome in biomeOrder) {
      if (!biomeRegions.containsKey(biome)) continue;

      paint.color = biomeColors[biome]!;

      // Apply XKCD wobble to paths
      for (final path in biomeRegions[biome]!) {
        final wobbledPath = _applyXKCDWobble(path, 2.0);

        // Add elevation shadow for non-water biomes
        if (biome != BiomeType.ocean && biome != BiomeType.lake) {
          final shadowPaint = Paint()
            ..color = Colors.black.withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

          canvas.drawPath(
            wobbledPath.shift(const Offset(2, 4)),
            shadowPaint,
          );
        }

        canvas.drawPath(wobbledPath, paint);
      }
    }
  }

  void _drawRivers(Canvas canvas) {
    final paint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final river in islandData.rivers) {
      if (river.path.length < 2) continue;

      // Width based on flow
      paint.strokeWidth = math.min(river.flow * 2, 6.0);

      final path = Path();
      path.moveTo(river.path[0].x, river.path[0].y);

      // Smooth curve through points
      for (int i = 1; i < river.path.length - 1; i++) {
        final p0 = river.path[i - 1];
        final p1 = river.path[i];
        final p2 = river.path[i + 1];

        final cp1 = Point2D(
          p0.x + (p1.x - p0.x) * 0.7,
          p0.y + (p1.y - p0.y) * 0.7,
        );

        final cp2 = Point2D(
          p1.x + (p2.x - p1.x) * 0.3,
          p1.y + (p2.y - p1.y) * 0.3,
        );

        path.quadraticBezierTo(cp1.x, cp1.y, p1.x, p1.y);
      }

      if (river.path.length > 1) {
        final last = river.path.last;
        path.lineTo(last.x, last.y);
      }

      canvas.drawPath(path, paint);
    }
  }

  void _drawCoastlines(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final coastline in islandData.coastlines) {
      final wobbledCoast = _applyXKCDWobble(coastline, 3.0);
      canvas.drawPath(wobbledCoast, paint);
    }
  }

  void _drawCompass(Canvas canvas, Size size) {
    final center = Offset(60, size.height - 60);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(0.1); // Slight rotation for character

    // White background
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 25, bgPaint);

    // Compass rose
    final rosePath = Path()
      ..moveTo(0, -30)
      ..lineTo(-5, 0)
      ..lineTo(0, 30)
      ..lineTo(5, 0)
      ..close();

    final rosePaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;
    canvas.drawPath(rosePath, rosePaint);

    // North pointer
    final northPath = Path()
      ..moveTo(-5, 0)
      ..lineTo(5, 0)
      ..lineTo(0, -30)
      ..close();

    final northPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, 25, outlinePaint);

    // N letter
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(-6, -45));

    canvas.restore();
  }

  Color _getElevationColor(double elevation) {
    if (elevation <= 0) return waterColor;
    if (elevation < 0.1) return sandColor;
    if (elevation < 0.3) return grassColor;
    if (elevation < 0.6) return forestColor;
    if (elevation < 0.8) return mountainColor;
    return snowColor;
  }

  Color _getMoistureColor(double moisture) {
    return Color.lerp(
      desertColor,
      waterColor,
      moisture,
    )!;
  }

  Path _applyXKCDWobble(Path path, double intensity) {
    final metrics = path.computeMetrics();
    final wobbledPath = Path();

    for (final metric in metrics) {
      bool first = true;

      for (double distance = 0; distance < metric.length; distance += 5) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) continue;

        final point = tangent.position;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

        // Multi-frequency wobble
        final wobble = math.sin(distance * 0.05) * intensity * 0.6 +
            math.sin(distance * 0.11) * intensity * 0.3 +
            math.sin(distance * 0.23) * intensity * 0.2;

        final wobbledPoint = point + normal * wobble;

        if (first) {
          wobbledPath.moveTo(wobbledPoint.dx, wobbledPoint.dy);
          first = false;
        } else {
          wobbledPath.lineTo(wobbledPoint.dx, wobbledPoint.dy);
        }
      }

      wobbledPath.close();
    }

    return wobbledPath;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
