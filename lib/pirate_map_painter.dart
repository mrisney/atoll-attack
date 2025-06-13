// pirate_map_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'alpha_shape.dart';

class PirateMapPainter extends CustomPainter {
  final List<List<Point2D>> islands;
  final Size mapSize;

  // XKCD-style colors
  static const oceanColor = Color(0xFF4FA5D5);
  static const deepOceanColor = Color(0xFF2E5984);
  static const sandColor = Color(0xFFFFFFA6);
  static const grassColor = Color(0xFFBDF271);
  static const darkGrassColor = Color(0xFF7A9F3C);
  static const mountainColor = Color(0xFFCFC291);
  static const outlineColor = Colors.black;

  PirateMapPainter({required this.islands, required this.mapSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Create ocean background with gradient
    _paintOcean(canvas, size);

    // Paint each island
    for (int i = 0; i < islands.length; i++) {
      if (islands[i].length > 2) {
        _paintIsland(canvas, islands[i], i);
      }
    }

    // Add decorative elements
    _paintDecorations(canvas, size);
  }

  void _paintOcean(Canvas canvas, Size size) {
    // Ocean gradient background
    final oceanGradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(0, size.height),
      [oceanColor, deepOceanColor],
    );

    final oceanPaint = Paint()
      ..shader = oceanGradient
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), oceanPaint);

    // Add subtle wave pattern
    _paintWaves(canvas, size);
  }

  void _paintWaves(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (double y = 0; y < size.height; y += 30) {
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x < size.width; x += 20) {
        path.lineTo(x, y + sin(x * 0.02) * 3);
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  void _paintIsland(
    Canvas canvas,
    List<Point2D> islandPoints,
    int islandIndex,
  ) {
    if (islandPoints.length < 3) return;

    // Create the base island path
    final islandPath = _createIslandPath(islandPoints);

    // Calculate island center and size for layering
    final bounds = islandPath.getBounds();
    final center = bounds.center;
    final maxSize = max(bounds.width, bounds.height);

    // Draw shallow water around island
    _drawShallowWater(canvas, islandPath, 3);

    // Draw sand/beach layer
    _drawLayer(canvas, islandPath, 1.0, sandColor, true);

    // Draw grass layer (smaller)
    final grassPath = _createScaledPath(islandPoints, center, 0.7);
    _drawLayer(canvas, grassPath, 0.9, grassColor, false);

    // Draw mountain/highland layer (even smaller)
    if (maxSize > 100) {
      // Only for larger islands
      final mountainPath = _createScaledPath(islandPoints, center, 0.4);
      _drawLayer(canvas, mountainPath, 0.8, darkGrassColor, false);
    }

    // Draw decorative elements
    _drawIslandDetails(canvas, bounds, maxSize);
  }

  void _drawShallowWater(Canvas canvas, Path islandPath, int rings) {
    final shallowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = rings; i > 0; i--) {
      final expandedPath = _expandPath(islandPath, i * 15.0);
      final color = Color.lerp(
        oceanColor,
        const Color(0xFF87CEEB),
        (rings - i) / rings,
      )!.withOpacity(0.3);

      shallowPaint.color = color;
      canvas.drawPath(expandedPath, shallowPaint);
    }
  }

  void _drawLayer(
    Canvas canvas,
    Path path,
    double elevation,
    Color color,
    bool isBase,
  ) {
    // Apply wobble for hand-drawn effect
    final wobbledPath = _applyWobble(path, isBase ? 3.0 : 2.0);

    // Draw shadow/elevation
    if (elevation < 1.0) {
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2 * elevation)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawPath(
        wobbledPath.shift(Offset(2 * elevation, 4 * elevation)),
        shadowPaint,
      );
    }

    // Fill the layer
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(wobbledPath, fillPaint);

    // Draw outline
    final outlinePaint = Paint()
      ..color = outlineColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(wobbledPath, outlinePaint);
  }

  void _drawIslandDetails(Canvas canvas, Rect bounds, double size) {
    final random = Random(bounds.hashCode);

    // Add some vegetation dots for larger islands
    if (size > 150) {
      final vegPaint = Paint()
        ..color = darkGrassColor.withOpacity(0.6)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < size / 30; i++) {
        final x =
            bounds.left +
            random.nextDouble() * bounds.width * 0.6 +
            bounds.width * 0.2;
        final y =
            bounds.top +
            random.nextDouble() * bounds.height * 0.6 +
            bounds.height * 0.2;

        canvas.drawCircle(Offset(x, y), 2 + random.nextDouble() * 2, vegPaint);
      }
    }

    // Add beach texture
    final beachPaint = Paint()
      ..color = mountainColor.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final length = 10 + random.nextDouble() * 20;
      final x = bounds.center.dx + cos(angle) * size * 0.3;
      final y = bounds.center.dy + sin(angle) * size * 0.3;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + cos(angle) * length, y + sin(angle) * length),
        beachPaint,
      );
    }
  }

  Path _createIslandPath(List<Point2D> points) {
    final path = Path();

    if (points.isEmpty) return path;

    // Start at first point
    path.moveTo(points[0].x, points[0].y);

    // Create smooth curves between points
    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      // Control points for smooth curve
      final cp1x = p1.x + (p2.x - p1.x) * 0.7;
      final cp1y = p1.y + (p2.y - p1.y) * 0.7;
      final cp2x = p2.x + (p3.x - p2.x) * 0.3;
      final cp2y = p2.y + (p3.y - p2.y) * 0.3;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
    }

    path.close();
    return path;
  }

  Path _createScaledPath(List<Point2D> points, Offset center, double scale) {
    final path = Path();

    if (points.isEmpty) return path;

    // Scale points toward center
    List<Point2D> scaledPoints = [];
    for (final point in points) {
      final dx = point.x - center.dx;
      final dy = point.y - center.dy;
      scaledPoints.add(Point2D(center.dx + dx * scale, center.dy + dy * scale));
    }

    return _createIslandPath(scaledPoints);
  }

  Path _expandPath(Path path, double amount) {
    final bounds = path.getBounds();
    final center = bounds.center;

    // Simple expansion by scaling
    final matrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(1.0 + amount / max(bounds.width, bounds.height))
      ..translate(-center.dx, -center.dy);

    return path.transform(matrix.storage);
  }

  Path _applyWobble(Path path, double intensity) {
    final metrics = path.computeMetrics();
    final wobbledPath = Path();

    for (final metric in metrics) {
      final points = <Offset>[];

      // Sample points along the path
      for (double distance = 0; distance < metric.length; distance += 5) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          final point = tangent.position;
          final normal = Offset(-tangent.vector.dy, tangent.vector.dx);

          // Multi-frequency wobble for natural look
          final wobble =
              sin(distance * 0.1) * intensity * 0.5 +
              sin(distance * 0.23) * intensity * 0.3 +
              sin(distance * 0.37) * intensity * 0.2;

          points.add(point + normal * wobble);
        }
      }

      // Rebuild path from wobbled points
      if (points.isNotEmpty) {
        wobbledPath.moveTo(points.first.dx, points.first.dy);
        for (int i = 1; i < points.length; i++) {
          wobbledPath.lineTo(points[i].dx, points[i].dy);
        }
        wobbledPath.close();
      }
    }

    return wobbledPath;
  }

  void _paintDecorations(Canvas canvas, Size size) {
    // Add compass rose
    _paintCompass(canvas, Offset(size.width - 80, 80));

    // Add map border
    _paintBorder(canvas, size);
  }

  void _paintCompass(Canvas canvas, Offset center) {
    final compassPaint = Paint()
      ..color = mountainColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Outer circle
    canvas.drawCircle(center, 30, compassPaint);

    // Inner decorations
    final fillPaint = Paint()
      ..color = mountainColor
      ..style = PaintingStyle.fill;

    // North arrow
    final northPath = Path()
      ..moveTo(center.dx, center.dy - 25)
      ..lineTo(center.dx - 5, center.dy - 10)
      ..lineTo(center.dx, center.dy - 15)
      ..lineTo(center.dx + 5, center.dy - 10)
      ..close();

    canvas.drawPath(northPath, fillPaint);

    // N letter
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: mountainColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - 6, center.dy - 50));
  }

  void _paintBorder(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = mountainColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final borderPath = Path()
      ..addRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4));

    canvas.drawPath(_applyWobble(borderPath, 2), borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
