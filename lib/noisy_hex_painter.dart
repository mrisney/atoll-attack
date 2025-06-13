// lib/noisy_hex_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;

class NoisyHexPainter extends CustomPainter {
  final double amplitude;
  final double wavelength;
  final double bias;
  final int seed;
  final double blur;
  final Size canvasSize;

  late fn.SimplexNoise noise;

  // Colors matching Red Blob Games exactly
  static const Color color0 =
      Color.fromRGBO(179, 153, 230, 1.0); // RGB(0.7, 0.6, 0.9)
  static const Color color1 =
      Color.fromRGBO(135, 128, 128, 1.0); // RGB(0.53, 0.5, 0.5)
  static const Color color2 =
      Color.fromRGBO(110, 102, 102, 1.0); // RGB(0.43, 0.4, 0.4)

  NoisyHexPainter({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.blur,
    required this.canvasSize,
  }) {
    noise = fn.SimplexNoise(seed: seed, frequency: 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Create the hexagon structure exactly like Red Blob Games
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.3;

    // Red Blob Games renders 6 triangles that form a hexagon
    // Each triangle has barycentric coordinates for 3 colors
    _renderNoisyHexTriangles(canvas, center, radius, size);
  }

  void _renderNoisyHexTriangles(
      Canvas canvas, Offset center, double radius, Size size) {
    // Create 6 triangles like Red Blob Games
    for (int dir = 0; dir < 6; dir++) {
      double angle0 = dir / 6 * 2 * pi;
      double angle1 = (dir + 1) / 6 * 2 * pi;

      // Triangle vertices (center + 2 edge points)
      Offset vertex0 = center;
      Offset vertex1 =
          center + Offset(radius * cos(angle0), radius * sin(angle0));
      Offset vertex2 =
          center + Offset(radius * cos(angle1), radius * sin(angle1));

      // Assign barycentric coordinates like Red Blob Games vertex shader
      // Each vertex gets different color weights
      List<Vector3> barycentrics = [
        Vector3(0.7, 0.2, 0.1), // Center vertex
        Vector3(0.1, 0.8, 0.1), // First edge
        Vector3(0.1, 0.1, 0.8), // Second edge
      ];

      List<Color> vertexColors = [color0, color1, color2];

      _renderNoisyTriangle(canvas, [vertex0, vertex1, vertex2], barycentrics,
          vertexColors, size);
    }
  }

  void _renderNoisyTriangle(Canvas canvas, List<Offset> vertices,
      List<Vector3> barycentrics, List<Color> colors, Size size) {
    // Create a high-resolution triangle mesh
    int subdivisions = 50;

    for (int i = 0; i < subdivisions; i++) {
      for (int j = 0; j < subdivisions - i; j++) {
        // Create sub-triangle coordinates
        double u = i / subdivisions.toDouble();
        double v = j / subdivisions.toDouble();
        double w = 1.0 - u - v;

        if (w < 0) continue; // Outside triangle

        // Interpolate position using barycentric coordinates
        Offset pos = Offset(
          vertices[0].dx * u + vertices[1].dx * v + vertices[2].dx * w,
          vertices[0].dy * u + vertices[1].dy * v + vertices[2].dy * w,
        );

        // Interpolate barycentric coordinates
        Vector3 interpolatedBary = Vector3(
          barycentrics[0].x * u + barycentrics[1].x * v + barycentrics[2].x * w,
          barycentrics[0].y * u + barycentrics[1].y * v + barycentrics[2].y * w,
          barycentrics[0].z * u + barycentrics[1].z * v + barycentrics[2].z * w,
        );

        // Apply the Red Blob Games noise algorithm
        Color finalColor = _applyNoisyHexAlgorithm(pos, interpolatedBary, size);

        // Draw pixel
        Paint pixelPaint = Paint()
          ..color = finalColor
          ..strokeWidth = 2.0;

        canvas.drawCircle(pos, 1.0, pixelPaint);
      }
    }
  }

  Color _applyNoisyHexAlgorithm(
      Offset position, Vector3 barycentric, Size size) {
    // Convert position to Red Blob Games coordinate system
    Offset centered = position - Offset(size.width / 2, size.height / 2);
    Vector2 v_position = Vector2(
      centered.dx / min(size.width, size.height),
      centered.dy / min(size.width, size.height),
    );

    // Base color interpolation
    Color baseColor = Color.lerp(
      Color.lerp(color0, color1, barycentric.y)!,
      color2,
      barycentric.z,
    )!;

    // EXACT Red Blob Games noise application
    Vector2 offset = v_position / wavelength;

    // Apply noise to barycentric coordinates with seed offset
    Vector3 noisy = Vector3(
      barycentric.x +
          bias +
          amplitude *
              _getNoise3D(offset.x, offset.y, color0.blue / 255.0 + seed),
      barycentric.y +
          amplitude *
              _getNoise3D(offset.x, offset.y, color1.blue / 255.0 + seed),
      barycentric.z +
          amplitude *
              _getNoise3D(offset.x, offset.y, color2.blue / 255.0 + seed),
    );

    // Red Blob Games color mixing algorithm
    double mixFactor =
        _smoothstep(blur, -blur, noisy.x - max(noisy.y, noisy.z));
    Color finalColor = Color.lerp(color0, color1, mixFactor)!;

    // Add border effect
    double minBary = min(barycentric.x, min(barycentric.y, barycentric.z));
    double borderFactor = _smoothstep(0.0, 0.005, minBary);

    return Color.fromRGBO(
      (finalColor.red * borderFactor).round(),
      (finalColor.green * borderFactor).round(),
      (finalColor.blue * borderFactor).round(),
      1.0,
    );
  }

  double _getNoise3D(double x, double y, double z) {
    // Use the noise generator to simulate the 3D noise from Red Blob Games
    return noise.getNoise2(x * 100, y * 100) * 0.5 +
        noise.getNoise2(x * 100 + z * 1000, y * 100 + z * 1000) * 0.5;
  }

  double _smoothstep(double edge0, double edge1, double x) {
    double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  double max(double a, double b) => a > b ? a : b;
  double min(double a, double b) => a < b ? a : b;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Helper classes
class Vector2 {
  final double x, y;
  Vector2(this.x, this.y);
  Vector2 operator /(double scalar) => Vector2(x / scalar, y / scalar);
}

class Vector3 {
  final double x, y, z;
  Vector3(this.x, this.y, this.z);
}
