// lib/game/hybrid/organic_island_game.dart
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:typed_data';

class OrganicIslandGame extends FlameGame
    with TapDetector, PanDetector, ScrollDetector {
  late IslandComponent island;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB); // Sky blue

  @override
  Future<void> onLoad() async {
    // Create the island component
    island = IslandComponent();
    add(island);

    // Set initial camera
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.position = Vector2(size.x / 2, size.y / 2);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.zoom =
        (zoom - info.scrollDelta.global.y * 0.001).clamp(0.5, 3.0);
  }

  @override
  void onTapDown(TapDownInfo info) {
    // Regenerate island on tap
    island.regenerateIsland();
  }
}

class IslandComponent extends PositionComponent {
  // Color palette
  static const waterColor = Color(0xFF2185C5);
  static const shallowWaterColor = Color(0xFF4FA9E1);
  static const sandColor = Color(0xFFFFFFA6);
  static const grassColor = Color(0xFFBDF271);
  static const darkSandColor = Color(0xFFCFC291);
  static const pathColor = Color(0xFFDC3522);

  late IslandData islandData;
  final math.Random random = math.Random();

  @override
  Future<void> onLoad() async {
    size = Vector2(1024, 1024);
    position = Vector2.zero();
    generateIsland();
  }

  void regenerateIsland() {
    generateIsland();
  }

  void generateIsland() {
    // Create island data
    islandData = IslandData();
    final center = Vector2(size.x / 2, size.y / 2);
    
    // Generate main island shape (beach)
    islandData.beachPath = createOrganicShape(
      center,
      size.x * 0.4, // radius
      60, // points
      0.3, // noise amplitude
    );
    
    // Generate grass area
    islandData.grassPath = createOrganicShape(
      center,
      size.x * 0.3, // smaller radius
      50, // points
      0.25, // noise amplitude
    );
    
    // Generate highland area
    islandData.highlandPath = createOrganicShape(
      center,
      size.x * 0.15, // even smaller radius
      40, // points
      0.2, // noise amplitude
    );
    
    // Generate grass patches
    for (int i = 0; i < 3; i++) {
      final patchCenter = Vector2(
        center.x + (random.nextDouble() - 0.5) * size.x * 0.3,
        center.y + (random.nextDouble() - 0.5) * size.y * 0.3,
      );
      
      final patch = createOrganicShape(
        patchCenter,
        size.x * 0.08, // small radius
        30, // points
        0.4, // noise amplitude
      );
      
      islandData.grassPatches.add(patch);
    }
    
    // Generate treasure path
    generateTreasurePath();
  }

  Path createOrganicShape(
    Vector2 center,
    double radius,
    int numPoints,
    double noiseAmplitude,
  ) {
    final path = Path();
    final basePoints = <Vector2>[];
    
    // Generate base points around a circle
    for (int i = 0; i < numPoints; i++) {
      final angle = i * (2 * math.pi / numPoints);
      
      // Multi-frequency noise for natural coastlines
      final noise = 
          math.sin(angle * 2) * 0.1 +
          math.sin(angle * 5) * 0.05 +
          math.sin(angle * 9) * 0.025 +
          random.nextDouble() * noiseAmplitude;
      
      // Adjust radius with noise
      final adjustedRadius = radius * (1.0 + noise);
      
      // Calculate point position
      final x = center.x + math.cos(angle) * adjustedRadius;
      final y = center.y + math.sin(angle) * adjustedRadius;
      
      basePoints.add(Vector2(x, y));
    }
    
    // Create smooth path with bezier curves
    if (basePoints.isNotEmpty) {
      path.moveTo(basePoints.first.x, basePoints.first.y);
      
      for (int i = 0; i < basePoints.length; i++) {
        final current = basePoints[i];
        final next = basePoints[(i + 1) % basePoints.length];
        final nextNext = basePoints[(i + 2) % basePoints.length];
        
        // Control points for smooth curves
        final control1 = Vector2(
          current.x + (next.x - current.x) * 0.5 + (random.nextDouble() - 0.5) * 10,
          current.y + (next.y - current.y) * 0.5 + (random.nextDouble() - 0.5) * 10,
        );
        
        final control2 = Vector2(
          next.x + (nextNext.x - next.x) * 0.5 + (random.nextDouble() - 0.5) * 10,
          next.y + (nextNext.y - next.y) * 0.5 + (random.nextDouble() - 0.5) * 10,
        );
        
        // Add cubic bezier curve
        path.cubicTo(
          control1.x, control1.y,
          control2.x, control2.y,
          next.x, next.y
        );
      }
    }
    
    path.close();
    return path;
  }

  void generateTreasurePath() {
    final path = Path();
    final center = Vector2(size.x / 2, size.y / 2);
    
    // Create start and end points
    final startPoint = Vector2(
      size.x * 0.2 + random.nextDouble() * 50,
      size.y * 0.6 + (random.nextDouble() - 0.5) * 100,
    );
    
    final endPoint = Vector2(
      center.x + (random.nextDouble() - 0.5) * 50,
      center.y + (random.nextDouble() - 0.5) * 50,
    );
    
    // Create curved path
    path.moveTo(startPoint.x, startPoint.y);
    
    // Control points for the curve
    final control1 = Vector2(
      startPoint.x + (endPoint.x - startPoint.x) * 0.3,
      startPoint.y - 50,
    );
    
    final control2 = Vector2(
      startPoint.x + (endPoint.x - startPoint.x) * 0.7,
      endPoint.y + 30,
    );
    
    // Add cubic bezier curve
    path.cubicTo(
      control1.x, control1.y,
      control2.x, control2.y,
      endPoint.x, endPoint.y,
    );
    
    islandData.treasurePath = path;
    islandData.treasureStart = startPoint;
    islandData.treasureEnd = endPoint;
  }

  @override
  void render(Canvas canvas) {
    // Apply slight rotation for isometric feel
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(-0.2); // Isometric rotation
    canvas.translate(-size.x / 2, -size.y / 2);
    
    // Draw water background
    final waterPaint = Paint()
      ..color = waterColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), waterPaint);
    
    // Draw water pattern
    drawWaterPattern(canvas);
    
    // Draw shallow water rings
    drawShallowWater(canvas);
    
    // Draw island layers
    drawIslandLayers(canvas);
    
    // Draw treasure path
    drawTreasurePath(canvas);
    
    // Draw compass
    drawCompass(canvas);
    
    canvas.restore();
  }

  void drawWaterPattern(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw wave lines
    for (int i = 0; i < 30; i++) {
      final y = i * 30.0;
      final wavePath = Path();
      wavePath.moveTo(0, y);
      
      for (double x = 0; x < size.x; x += 15) {
        final waveY = y + math.sin(x * 0.02 + i) * 8;
        wavePath.lineTo(x, waveY);
      }
      
      canvas.drawPath(wavePath, paint);
    }
  }

  void drawShallowWater(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    // Draw multiple shallow water rings
    for (int i = 4; i > 0; i--) {
      final expandedPath = expandPath(islandData.beachPath, i * 40.0);
      
      paint.color = Color.lerp(
        shallowWaterColor, 
        waterColor, 
        i / 4.0
      )!.withOpacity(0.5);
      
      canvas.drawPath(expandedPath, paint);
    }
  }

  Path expandPath(Path path, double distance) {
    // Create a new expanded path by sampling points
    final bounds = path.getBounds();
    final center = bounds.center;
    final newPath = Path();
    
    // Sample the original path
    final metrics = path.computeMetrics();
    
    for (final metric in metrics) {
      bool first = true;
      final pointCount = (metric.length / 5).ceil();
      
      for (int i = 0; i < pointCount; i++) {
        final distance = i * metric.length / pointCount;
        final tangent = metric.getTangentForOffset(distance);
        if (tangent == null) continue;
        
        final pos = tangent.position;
        
        // Calculate vector from center to point
        final dx = pos.dx - center.dx;
        final dy = pos.dy - center.dy;
        final len = math.sqrt(dx * dx + dy * dy);
        
        if (len < 0.001) continue;
        
        // Expand outward
        final newX = center.dx + dx / len * (len + distance);
        final newY = center.dy + dy / len * (len + distance);
        
        if (first) {
          newPath.moveTo(newX, newY);
          first = false;
        } else {
          newPath.lineTo(newX, newY);
        }
      }
      
      newPath.close();
    }
    
    return newPath;
  }

  void drawIslandLayers(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.black.withOpacity(0.8);
    
    // Draw beach layer with shadows
    final beachPath = applyWobble(islandData.beachPath, 3.0);
    
    // Draw elevation shadows
    for (int i = 4; i > 0; i--) {
      final shadowPath = beachPath.shift(Offset(i * 1.0, i * 2.0));
      paint.color = darkSandColor.withOpacity(0.2);
      canvas.drawPath(shadowPath, paint);
    }
    
    // Main beach
    paint.color = sandColor;
    canvas.drawPath(beachPath, paint);
    canvas.drawPath(beachPath, outlinePaint);
    
    // Draw grass layer
    final grassPath = applyWobble(islandData.grassPath, 2.5);
    
    // Grass shadows
    for (int i = 2; i > 0; i--) {
      final shadowPath = grassPath.shift(Offset(i * 0.5, i * 1.0));
      paint.color = Colors.black.withOpacity(0.15);
      canvas.drawPath(shadowPath, paint);
    }
    
    paint.color = grassColor;
    canvas.drawPath(grassPath, paint);
    canvas.drawPath(grassPath, outlinePaint);
    
    // Draw grass patches
    for (final patch in islandData.grassPatches) {
      final patchPath = applyWobble(patch, 2.0);
      paint.color = grassColor.withGreen(200);
      canvas.drawPath(patchPath, paint);
      outlinePaint.strokeWidth = 1.5;
      canvas.drawPath(patchPath, outlinePaint);
    }
    
    // Draw highland layer
    final highlandPath = applyWobble(islandData.highlandPath, 2.0);
    paint.color = darkSandColor;
    canvas.drawPath(highlandPath, paint);
    canvas.drawPath(highlandPath, outlinePaint);
  }

  Path applyWobble(Path path, double intensity) {
    // Add hand-drawn wobble effect to path
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

  void drawTreasurePath(Canvas canvas) {
    final paint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    // Create dashed path
    final dashedPath = createDashedPath(islandData.treasurePath);
    canvas.drawPath(dashedPath, paint);
    
    // Draw X marks
    drawXMark(canvas, islandData.treasureStart, 10, Colors.black);
    drawXMark(canvas, islandData.treasureEnd, 14, pathColor);
  }

  Path createDashedPath(Path source) {
    final metrics = source.computeMetrics();
    final dashedPath = Path();
    
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      
      while (distance < metric.length) {
        if (draw) {
          final start = distance;
          final end = math.min(distance + 12, metric.length);
          dashedPath.addPath(
            metric.extractPath(start, end),
            Offset.zero,
          );
        }
        distance += draw ? 12 : 6;
        draw = !draw;
      }
    }
    
    return dashedPath;
  }

  void drawXMark(Canvas canvas, Vector2 pos, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(pos.x - size, pos.y - size),
      Offset(pos.x + size, pos.y + size),
      paint,
    );
    
    canvas.drawLine(
      Offset(pos.x + size, pos.y - size),
      Offset(pos.x - size, pos.y + size),
      paint,
    );
  }

  void drawCompass(Canvas canvas) {
    final center = Offset(80, size.y - 80);
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(random.nextDouble() * 0.2 - 0.1);
    
    // White background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 30, bgPaint);
    
    // Compass rose
    final rosePath = Path()
      ..moveTo(0, -35)
      ..lineTo(-5, 0)
      ..lineTo(0, 35)
      ..lineTo(5, 0)
      ..close();
    
    final rosePaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;
    canvas.drawPath(rosePath, rosePaint);
    
    // North pointer
    final northPath = Path()
      ..moveTo(-5, 0)
      ..lineTo(5, 0)
      ..lineTo(0, -35)
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
    canvas.drawCircle(Offset.zero, 30, outlinePaint);
    
    // N letter
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(-8, -55));
    
    canvas.restore();
  }
}

class IslandData {
  late Path beachPath;
  late Path grassPath;
  late Path highlandPath;
  late Path treasurePath;
  late Vector2 treasureStart;
  late Vector2 treasureEnd;
  final List<Path> grassPatches = [];
}