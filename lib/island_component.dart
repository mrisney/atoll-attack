import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A GPU-accelerated island renderer component using a fragment shader.
class IslandComponent extends PositionComponent {
  double radius;
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;

  // Shader resources
  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;

  // CPU fallback noise for gameplay queries and fallback rendering
  late fn.SimplexNoise noise;

  IslandComponent({
    required this.radius,
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
  }) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    noise = fn.SimplexNoise(seed: seed, frequency: wavelength * 0.01);
    await _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      fragmentProgram =
          await ui.FragmentProgram.fromAsset('shaders/noisy_hex.frag');
      shader = fragmentProgram!.fragmentShader();
      shaderLoaded = true;
    } catch (e) {
      shaderLoaded = false;
      debugPrint('Failed to load fragment shader: $e');
    }
  }

  /// Update shader and fallback noise parameters
  void updateParams({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    noise = fn.SimplexNoise(seed: seed, frequency: wavelength * 0.01);
  }

  @override
  void render(Canvas canvas) {
    // Center the coordinate system for consistent shader mapping
    canvas.save();
    canvas.translate(gameSize.x / 2, gameSize.y / 2);

    if (shaderLoaded && shader != null) {
      _renderShaderIsland(canvas);
    } else {
      _renderFallback(canvas);
    }
    canvas.restore();
  }

  void _renderShaderIsland(Canvas canvas) {
    // Pass uniforms to shader: amplitude, wavelength, bias, seed, resolution x/y
    shader!
      ..setFloat(0, amplitude)
      ..setFloat(1, wavelength)
      ..setFloat(2, bias)
      ..setFloat(3, seed.toDouble())
      ..setFloat(4, gameSize.x)
      ..setFloat(5, gameSize.y);

    final paint = Paint()..shader = shader;
    // Draw a rectangle centered at (0,0) covering the full render area
    canvas.drawRect(
      Rect.fromLTWH(-gameSize.x / 2, -gameSize.y / 2, gameSize.x, gameSize.y),
      paint,
    );
  }

  void _renderFallback(Canvas canvas) {
    final maxRadius = gameSize.x * 0.4;
    // Water background
    canvas.drawRect(
      Rect.fromLTWH(-gameSize.x / 2, -gameSize.y / 2, gameSize.x, gameSize.y),
      Paint()..color = const Color(0xFF1E88E5),
    );

    // Irregular island polygon
    final islandPaint = Paint()..color = const Color(0xFF4CAF50);
    final center = Offset.zero;
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
