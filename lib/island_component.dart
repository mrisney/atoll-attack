import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;

class IslandComponent extends PositionComponent {
  double radius;
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;

  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;

  late fn.SimplexNoise noise;

  List<Vector2> _perimeter = [];
  bool showPerimeter = false;
  bool _perimeterDirty = true;

  IslandComponent({
    required this.radius,
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
    required this.islandRadius,
    this.showPerimeter = false,
  }) {
    anchor = Anchor.center;
    size = gameSize;
    position = gameSize / 2;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    noise = fn.SimplexNoise(seed: seed, frequency: wavelength * 0.01);
    await _loadShader();
    _perimeterDirty = true;
  }

  Future<void> _loadShader() async {
    try {
      fragmentProgram =
          await ui.FragmentProgram.fromAsset('shaders/island_water.frag');
      shader = fragmentProgram!.fragmentShader();
      shaderLoaded = true;
    } catch (e) {
      shaderLoaded = false;
      debugPrint('Failed to load fragment shader: $e');
    }
  }

  void updateParams({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required double islandRadius,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    this.islandRadius = islandRadius;
    noise = fn.SimplexNoise(seed: seed, frequency: wavelength * 0.01);
    _perimeterDirty = true;
  }

  @override
  void render(Canvas canvas) {
    if (shaderLoaded && shader != null) {
      _renderShaderIsland(canvas);
    } else {
      _renderFallback(canvas);
    }

    if (showPerimeter) {
      _drawGrid(canvas); // Draw grid cells, for debugging
      _drawPerimeter(canvas);
    }
  }

  void _renderShaderIsland(Canvas canvas) {
    shader!
      ..setFloat(0, amplitude)
      ..setFloat(1, wavelength)
      ..setFloat(2, bias)
      ..setFloat(3, seed.toDouble())
      ..setFloat(4, gameSize.x)
      ..setFloat(5, gameSize.y)
      ..setFloat(6, islandRadius);

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameSize.x, gameSize.y),
      paint,
    );
  }

  void _renderFallback(Canvas canvas) {
    final maxRadius = gameSize.x * 0.4 * islandRadius / 0.8;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, gameSize.x, gameSize.y),
      Paint()..color = const Color(0xFF1E88E5),
    );
    final islandPaint = Paint()..color = const Color(0xFF4CAF50);
    final center = Offset(gameSize.x / 2, gameSize.y / 2);
    for (int angle = 0; angle < 360; angle += 10) {
      double rad1 = angle * math.pi / 180;
      double rad2 = (angle + 10) * math.pi / 180;
      double n1 = noise.getNoise2(math.cos(rad1) * 0.1, math.sin(rad1) * 0.1);
      double n2 = noise.getNoise2(math.cos(rad2) * 0.1, math.sin(rad2) * 0.1);

      double r1 = maxRadius * (0.6 + 0.4 * n1);
      double r2 = maxRadius * (0.6 + 0.4 * n2);

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
            center.dx + r1 * math.cos(rad1), center.dy + r1 * math.sin(rad1))
        ..lineTo(
            center.dx + r2 * math.cos(rad2), center.dy + r2 * math.sin(rad2))
        ..close();

      canvas.drawPath(path, islandPaint);
    }
  }

  void _drawGrid(Canvas canvas, {int gridSteps = 40}) {
    // Draw thin black lines for the marching squares grid.
    final double step = (radius * 2) / gridSteps;
    final Paint gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double left = position.x - radius;
    final double top = position.y - radius;

    // Vertical lines
    for (int i = 0; i <= gridSteps; i++) {
      final x = left + i * step;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + 2 * radius),
        gridPaint,
      );
    }
    // Horizontal lines
    for (int j = 0; j <= gridSteps; j++) {
      final y = top + j * step;
      canvas.drawLine(
        Offset(left, y),
        Offset(left + 2 * radius, y),
        gridPaint,
      );
    }
  }

  /// Helper: chain unordered segment pairs into a continuous contour/polyline
  List<Vector2> _chainSegments(List<Vector2> segments, {double epsilon = 0.5}) {
    if (segments.length < 4) return segments;
    // Pair up segments by proximity, not equality
    List<Vector2> ordered = [segments[0]];
    Vector2 current = segments[1];
    ordered.add(current);
    segments = segments.sublist(2);

    while (segments.isNotEmpty) {
      bool found = false;
      for (int i = 0; i < segments.length; i += 2) {
        if ((segments[i] - current).length < epsilon) {
          current = segments[i + 1];
          ordered.add(current);
          segments.removeAt(i + 1);
          segments.removeAt(i);
          found = true;
          break;
        } else if ((segments[i + 1] - current).length < epsilon) {
          current = segments[i];
          ordered.add(current);
          segments.removeAt(i + 1);
          segments.removeAt(i);
          found = true;
          break;
        }
      }
      if (!found) break; // Can't chain further
    }
    return ordered;
  }

  void _drawPerimeter(Canvas canvas) {
    if (_perimeterDirty || _perimeter.isEmpty) {
      _perimeter = computePerimeter(isoLevel: -0.5);
      _perimeterDirty = false;
      debugPrint('Perimeter points: ${_perimeter.length}');
    }
    if (_perimeter.length < 2) return;

    final ordered = _chainSegments(_perimeter);
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(ordered[0].x, ordered[0].y);
    for (int i = 1; i < ordered.length; i++) {
      path.lineTo(ordered[i].x, ordered[i].y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Computes the coastline perimeter as a list of Vector2 points using the marching squares algorithm.
  /// The grid is centered on the island, and isoLevel determines the elevation threshold for the land/water boundary.
  List<Vector2> computePerimeter({
    int gridSteps = 80,
    double isoLevel = 0.0,
  }) {
    final List<Vector2> outline = [];
    final double step = (radius * 2) / gridSteps;
    final List<List<double>> elevations = List.generate(
      gridSteps + 1,
      (_) => List.filled(gridSteps + 1, 0.0),
    );

    // DEBUG: Track min/max elevation and counts for land/water
    double minElevation = double.infinity;
    double maxElevation = -double.infinity;
    int landCount = 0, waterCount = 0;

    // Precompute elevations for every grid point
    for (int i = 0; i <= gridSteps; i++) {
      for (int j = 0; j <= gridSteps; j++) {
        final localX = -radius + i * step;
        final localY = -radius + j * step;
        final worldPos = position + Vector2(localX, localY);
        final elev = getElevationAt(worldPos);
        elevations[i][j] = elev;
        if (elev < minElevation) minElevation = elev;
        if (elev > maxElevation) maxElevation = elev;
        if (elev > isoLevel) {
          landCount++;
        } else {
          waterCount++;
        }
      }
    }

    debugPrint(
        "computePerimeter isoLevel=$isoLevel minElev=$minElevation maxElev=$maxElevation land=$landCount water=$waterCount");

    // If all are land or all are water, perimeter can't be found
    if (landCount == 0 || waterCount == 0) {
      debugPrint(
          "computePerimeter: Entire grid is land or water, adjust isoLevel!");
      return outline;
    }

    // Marching squares: process each cell in the grid
    for (int i = 0; i < gridSteps; i++) {
      for (int j = 0; j < gridSteps; j++) {
        // Corners of the cell
        final x0 = -radius + i * step;
        final y0 = -radius + j * step;
        final x1 = x0 + step;
        final y1 = y0 + step;

        final p00 = position + Vector2(x0, y0);
        final p10 = position + Vector2(x1, y0);
        final p01 = position + Vector2(x0, y1);
        final p11 = position + Vector2(x1, y1);

        final e00 = elevations[i][j];
        final e10 = elevations[i + 1][j];
        final e01 = elevations[i][j + 1];
        final e11 = elevations[i + 1][j + 1];

        int idx = 0;
        if (e00 > isoLevel) idx |= 1;
        if (e10 > isoLevel) idx |= 2;
        if (e11 > isoLevel) idx |= 4;
        if (e01 > isoLevel) idx |= 8;

        if (idx == 0 || idx == 15) continue;

        Vector2 interp(Vector2 p1, Vector2 p2, double v1, double v2) {
          if ((v2 - v1).abs() < 1e-8) return p1;
          final t = (isoLevel - v1) / (v2 - v1);
          return p1 + (p2 - p1) * t;
        }

        switch (idx) {
          case 1:
          case 14:
            outline.add(interp(p00, p10, e00, e10));
            outline.add(interp(p00, p01, e00, e01));
            break;
          case 2:
          case 13:
            outline.add(interp(p10, p00, e10, e00));
            outline.add(interp(p10, p11, e10, e11));
            break;
          case 4:
          case 11:
            outline.add(interp(p11, p10, e11, e10));
            outline.add(interp(p11, p01, e11, e01));
            break;
          case 8:
          case 7:
            outline.add(interp(p01, p00, e01, e00));
            outline.add(interp(p01, p11, e01, e11));
            break;
          case 3:
          case 12:
            outline.add(interp(p00, p01, e00, e01));
            outline.add(interp(p10, p11, e10, e11));
            break;
          case 6:
          case 9:
            outline.add(interp(p10, p00, e10, e00));
            outline.add(interp(p11, p01, e11, e01));
            break;
          case 5:
          case 10:
            outline.add(interp(p00, p10, e00, e10));
            outline.add(interp(p01, p11, e01, e11));
            break;
        }
      }
    }

    debugPrint("computePerimeter: outline points = ${outline.length}");
    return outline;
  }

  double getElevationAt(Vector2 worldPosition) {
    Vector2 localPos = worldPosition - position;
    double distanceFromCenter = localPos.length;
    if (distanceFromCenter > radius * 1.2) return -1.0; // Deep water

    double elevation = noise.getNoise2(localPos.x * 0.01, localPos.y * 0.01);
    double islandFactor = 1.0 - (distanceFromCenter / radius);
    elevation *= islandFactor.clamp(0.0, 1.0);
    return elevation;
  }

  bool isOnLand(Vector2 worldPosition) => getElevationAt(worldPosition) > 0.0;

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    double elevation = getElevationAt(worldPosition);
    if (elevation <= 0.0) return 0.0;
    if (elevation < 0.2) return 1.0;
    if (elevation < 0.4) return 0.9;
    if (elevation < 0.6) return 0.7;
    if (elevation < 0.8) return 0.5;
    return 0.3;
  }

  @override
  void update(double dt) {
    // No per-frame logic needed for static island
  }
}
