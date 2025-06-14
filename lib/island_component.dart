import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart'; // for Vector2
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;

/// IslandComponent renders and describes a procedural island,
/// including coastline/perimeter sampling for gameplay logic.
class IslandComponent extends PositionComponent {
  double radius; // Gameplay radius, used for perimeter and queries
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius; // Value between 0.4 and 1.2 (controls falloff)

  // Shader resources
  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;

  // CPU fallback noise for gameplay queries and fallback rendering
  late fn.SimplexNoise noise;

  /// Perimeter points (sampled coastline), initialized after onLoad
  late List<Vector2> perimeter;

  /// Controls if perimeter is drawn (set by IslandGame)
  bool showPerimeter = false;

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
    perimeter = computePerimeter(numPoints: 180); // For gameplay/queries
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

  /// Update procedural params and re-sample perimeter
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
    perimeter = computePerimeter(numPoints: 180);
  }

  @override
  void render(Canvas canvas) {
    if (shaderLoaded && shader != null) {
      _renderShaderIsland(canvas);
    } else {
      _renderFallback(canvas);
    }
    if (showPerimeter) {
      _renderPerimeter(canvas);
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

  /// Draw perimeter for debug/visualization
  void _renderPerimeter(Canvas canvas) {
    if (perimeter.isEmpty) return;
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(perimeter[0].x, perimeter[0].y);
    for (final pt in perimeter) {
      path.lineTo(pt.x, pt.y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // --- Gameplay utilities ---

  /// Returns elevation at given world position (normalized, negative = water)
  double getElevationAt(Vector2 worldPosition) {
    Vector2 localPos = worldPosition - position;
    double distanceFromCenter = localPos.length;
    if (distanceFromCenter > radius * 1.2) return -1.0; // Deep water

    double elevation = noise.getNoise2(localPos.x * 0.01, localPos.y * 0.01);
    double islandFactor = 1.0 - (distanceFromCenter / radius);
    elevation *= islandFactor.clamp(0.0, 1.0);
    return elevation;
  }

  /// Returns true if world position is on land
  bool isOnLand(Vector2 worldPosition) => getElevationAt(worldPosition) > 0.0;

  /// Returns movement speed multiplier at world position
  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    double elevation = getElevationAt(worldPosition);
    if (elevation <= 0.0) return 0.0;
    if (elevation < 0.2) return 1.0;
    if (elevation < 0.4) return 0.9;
    if (elevation < 0.6) return 0.7;
    if (elevation < 0.8) return 0.5;
    return 0.3;
  }

  /// Compute the coastline/perimeter as a polyline of `numPoints` points.
  /// Each point is the farthest-on-land point in that direction from center.
  List<Vector2> computePerimeter({int numPoints = 180}) {
    List<Vector2> edgePoints = [];
    final center = position;
    final minR = radius * 0.6;
    final maxR = radius * 1.2;
    for (int i = 0; i < numPoints; i++) {
      double angle = (2 * math.pi * i) / numPoints;
      Vector2 pt = center;
      // Step radially outward until you leave land
      for (double r = minR; r < maxR; r += 2.0) {
        final testPt =
            center + Vector2(r * math.cos(angle), r * math.sin(angle));
        if (!isOnLand(testPt)) {
          // Step back for accuracy
          pt = center +
              Vector2((r - 2.0) * math.cos(angle), (r - 2.0) * math.sin(angle));
          break;
        }
      }
      edgePoints.add(pt);
    }
    return edgePoints;
  }

  /// Returns the closest perimeter point to [worldPosition]
  Vector2 closestPerimeterPoint(Vector2 worldPosition) {
    if (perimeter.isEmpty) return position;
    Vector2 closest = perimeter.first;
    double minDist = (worldPosition - closest).length2;
    for (final pt in perimeter) {
      final d = (worldPosition - pt).length2;
      if (d < minDist) {
        closest = pt;
        minDist = d;
      }
    }
    return closest;
  }

  /// Returns true if point is inside the perimeter polygon (crossing number method)
  bool isInsidePerimeter(Vector2 worldPosition) {
    if (perimeter.length < 3) return false;
    int crossings = 0;
    for (int i = 0; i < perimeter.length; i++) {
      final a = perimeter[i];
      final b = perimeter[(i + 1) % perimeter.length];
      if (((a.y > worldPosition.y) != (b.y > worldPosition.y)) &&
          (worldPosition.x <
              (b.x - a.x) * (worldPosition.y - a.y) / (b.y - a.y + 1e-9) +
                  a.x)) {
        crossings++;
      }
    }
    return (crossings % 2) == 1;
  }

  @override
  void update(double dt) {
    // No per-frame logic needed for static island
  }
}
