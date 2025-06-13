// lib/island_component.dart - GPU-based island with proper terrain colors
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
  // Removed blur parameter - it's hardcoded as 0.0
  int seed;
  Vector2 gameSize;

  // GPU shader properties
  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;

  // Fallback noise generator for gameplay features
  late fn.SimplexNoise noise;

  IslandComponent({
    required this.radius,
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    // Removed blur parameter
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
      print('GPU fragment shader loaded successfully');
    } catch (e) {
      print('Failed to load fragment shader: $e');
      shaderLoaded = false;
    }
  }

  void updateParams({
    required double amplitude,
    required double wavelength,
    required double bias,
    // Removed blur parameter
    required int seed,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    // Removed blur assignment
    this.seed = seed;

    // Update noise generator for gameplay features
    noise = fn.SimplexNoise(seed: seed, frequency: wavelength * 0.01);
  }

  @override
  void render(Canvas canvas) {
    if (shaderLoaded && shader != null) {
      // Update shader uniforms - EXACTLY 6 uniforms (remove u_blur since it's not needed)
      shader!.setFloat(0, amplitude); // u_amplitude
      shader!.setFloat(1, wavelength); // u_wavelength
      shader!.setFloat(2, bias); // u_bias
      shader!.setFloat(3, seed.toDouble()); // u_seed
      shader!.setFloat(4, gameSize.x); // u_resolution_x
      shader!.setFloat(5, gameSize.y); // u_resolution_y
      // Removed u_blur - it will be hardcoded in shader

      // Create paint with GPU shader
      final paint = Paint()..shader = shader;

      // Draw full screen rectangle - GPU handles all pixel processing
      canvas.drawRect(
        Rect.fromLTWH(-gameSize.x / 2, -gameSize.y / 2, gameSize.x, gameSize.y),
        paint,
      );
    } else {
      // Improved fallback - show a basic island shape
      _renderFallback(canvas);
    }
  }

  void _renderFallback(Canvas canvas) {
    // Create a simple island visualization as fallback
    final center = Offset.zero;
    final maxRadius = gameSize.x * 0.4;

    // Draw water background
    canvas.drawRect(
      Rect.fromLTWH(-gameSize.x / 2, -gameSize.y / 2, gameSize.x, gameSize.y),
      Paint()..color = const Color(0xFF1E88E5), // Blue water
    );

    // Draw island with noise-based irregular shape
    final islandPaint = Paint()..color = const Color(0xFF4CAF50); // Green land

    for (int angle = 0; angle < 360; angle += 10) {
      double radians = angle * math.pi / 180;
      double noiseValue = noise.getNoise2(
        math.cos(radians) * 0.1,
        math.sin(radians) * 0.1,
      );
      double currentRadius = maxRadius * (0.6 + 0.4 * noiseValue);

      double nextRadians = (angle + 10) * math.pi / 180;
      double nextNoiseValue = noise.getNoise2(
        math.cos(nextRadians) * 0.1,
        math.sin(nextRadians) * 0.1,
      );
      double nextRadius = maxRadius * (0.6 + 0.4 * nextNoiseValue);

      // Draw triangle from center to edge
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + currentRadius * math.cos(radians),
        center.dy + currentRadius * math.sin(radians),
      );
      path.lineTo(
        center.dx + nextRadius * math.cos(nextRadians),
        center.dy + nextRadius * math.sin(nextRadians),
      );
      path.close();

      canvas.drawPath(path, islandPaint);
    }
  }

  // Utility methods for gameplay
  double getElevationAt(Vector2 worldPosition) {
    Vector2 localPos = worldPosition - position;
    double distanceFromCenter = localPos.length;

    if (distanceFromCenter > radius * 1.2) {
      return -1.0; // Deep water
    }

    // Use noise for elevation variation
    double elevation = noise.getNoise2(
      localPos.x * 0.01,
      localPos.y * 0.01,
    );

    // Apply island falloff
    double islandFactor = 1.0 - (distanceFromCenter / radius);
    elevation *= islandFactor.clamp(0.0, 1.0);

    return elevation;
  }

  bool isOnLand(Vector2 worldPosition) {
    return getElevationAt(worldPosition) > 0.0;
  }

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    double elevation = getElevationAt(worldPosition);

    if (elevation <= 0.0) return 0.0; // Can't move in water
    if (elevation < 0.2) return 1.0; // Beach - normal speed
    if (elevation < 0.4) return 0.9; // Grass - slightly slower
    if (elevation < 0.6) return 0.7; // Hills - slower
    if (elevation < 0.8) return 0.5; // Mountains - much slower
    return 0.3; // High mountains - very slow
  }

  @override
  void update(double dt) {
    // No time-based updates needed for static terrain
  }
}
