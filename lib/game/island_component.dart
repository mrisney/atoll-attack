import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;

/// Enhanced IslandComponent with shader-based coordinate detection
class IslandComponent extends PositionComponent {
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  double radius;

  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;

  late fn.SimplexNoise noise;

  // Contour data
  Map<String, List<Offset>> _shaderContours = {};
  bool showPerimeter = false;
  bool _perimeterDirty = true;

  // Shader detection helper
  ShaderCoordinateExtractor? _coordinateExtractor;

  IslandComponent({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
    required this.islandRadius,
    this.showPerimeter = false,
  }) : radius = gameSize.x * 0.3 * islandRadius {
    anchor = Anchor.center;
    size = gameSize;
    position = gameSize / 2;
    noise = fn.SimplexNoise(seed: seed, frequency: 1.0);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadShader();
    _perimeterDirty = true;
  }

  Future<void> _loadShader() async {
    try {
      fragmentProgram =
          await ui.FragmentProgram.fromAsset('shaders/island_water.frag');
      shader = fragmentProgram!.fragmentShader();
      shaderLoaded = true;

      // Initialize coordinate extractor
      if (shader != null) {
        _coordinateExtractor =
            ShaderCoordinateExtractor(shader!, Size(size.x, size.y));
      }
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

    this.radius = gameSize.x * 0.3 * islandRadius;
    this.size = gameSize;
    this.position = gameSize / 2;

    noise = fn.SimplexNoise(seed: seed, frequency: 1.0);
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
      ..setFloat(6, islandRadius)
      ..setFloat(7, 0.0) // Normal rendering mode
      ..setFloat(8, 0.0); // Not used in normal mode

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint,
    );
  }

  void _renderFallback(Canvas canvas) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  void _drawPerimeter(Canvas canvas) {
    if (_perimeterDirty || _shaderContours.isEmpty) {
      _extractShaderContours();
      _perimeterDirty = false;
    }

    // Draw shader-detected contours
    final contourColors = {
      'coastline': Colors.purple,
      'shallow': Colors.cyan,
      'midland': Colors.orange,
      'highland': Colors.red,
    };

    for (final entry in _shaderContours.entries) {
      if (entry.value.length < 3) continue;

      final paint = Paint()
        ..color = contourColors[entry.key] ?? Colors.white
        ..strokeWidth = entry.key == 'coastline' ? 3.0 : 2.0
        ..style = PaintingStyle.stroke;

      final debugPaint = Paint()
        ..color = (contourColors[entry.key] ?? Colors.white).withOpacity(0.6)
        ..strokeWidth = 1.0;

      // Draw the contour
      final path = Path();
      if (entry.value.isNotEmpty) {
        path.moveTo(entry.value[0].dx, entry.value[0].dy);
        for (int i = 1; i < entry.value.length; i++) {
          path.lineTo(entry.value[i].dx, entry.value[i].dy);
        }
        path.close();
      }

      canvas.drawPath(path, paint);

      // Draw debug points
      for (final pt in entry.value) {
        canvas.drawCircle(pt, 1.5, debugPaint);
      }
    }
  }

  /// Extract contours using shader-based detection (async)
  Future<void> _extractShaderContours() async {
    if (_coordinateExtractor == null) return;

    try {
      final extractedContours = await _coordinateExtractor!.extractAllContours(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );

      _shaderContours = extractedContours;
      debugPrint(
          'Extracted ${_shaderContours.length} contour levels using shader detection');
    } catch (e) {
      debugPrint('Shader contour extraction failed: $e');
      _shaderContours = {};
    }
  }

  /// Dart translation of shader's elevation function (kept for compatibility)
  double getElevationAt(Vector2 centered) {
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

  Vector2 toCentered(Vector2 worldPosition) {
    double minRes = math.min(size.x, size.y);
    double cx = (worldPosition.x - size.x / 2) / (0.5 * minRes);
    double cy = (worldPosition.y - size.y / 2) / (0.5 * minRes);
    return Vector2(cx, cy);
  }

  // Public API methods
  bool isOnLand(Vector2 worldPosition) {
    return getElevationAt(toCentered(worldPosition)) > 0.32;
  }

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    double e = getElevationAt(toCentered(worldPosition));
    if (e <= 0.32) return 0.0; // water
    if (e < 0.39) return 0.9; // sand/lowland
    if (e < 0.54) return 0.8; // lowland
    if (e < 0.7) return 0.6; // upland
    return 0.5; // peak
  }

  int getElevationLevel(Vector2 worldPosition) {
    double e = getElevationAt(toCentered(worldPosition));
    if (e <= 0.18) return 0; // Deep water
    if (e <= 0.32) return 1; // Shallow water
    if (e < 0.50) return 2; // Low land
    if (e < 0.70) return 3; // Mid elevation
    return 4; // High peaks
  }

  /// Get all contours (shader-detected)
  Map<String, List<Offset>> getContours() {
    return Map.from(_shaderContours);
  }

  /// Get coastline specifically
  List<Offset> getCoastline() {
    return _shaderContours['coastline'] ?? [];
  }

  /// Get high ground perimeter
  List<Offset> getHighGroundPerimeter() {
    return _shaderContours['highland'] ?? [];
  }

  /// Force contour re-extraction
  Future<void> refreshContours() async {
    _perimeterDirty = true;
    await _extractShaderContours();
  }

  @override
  void update(double dt) {}
}

/// Helper class for shader coordinate extraction
class ShaderCoordinateExtractor {
  final ui.FragmentShader shader;
  final Size size;

  ShaderCoordinateExtractor(this.shader, this.size);

  /// Extract all contour levels
  Future<Map<String, List<Offset>>> extractAllContours({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required double islandRadius,
  }) async {
    final contours = <String, List<Offset>>{};

    // Define elevation thresholds
    final thresholds = {
      'coastline': 0.32,
      'shallow': 0.18,
      'midland': 0.50,
      'highland': 0.70,
    };

    for (final entry in thresholds.entries) {
      final coordinates = await _extractCoordinatesForThreshold(
        threshold: entry.value,
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );

      if (coordinates.isNotEmpty) {
        contours[entry.key] = coordinates;
      }
    }

    return contours;
  }

  /// Extract coordinates for a specific threshold with adaptive smoothing
  Future<List<Offset>> _extractCoordinatesForThreshold({
    required double threshold,
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required double islandRadius,
  }) async {
    // Set shader parameters for detection mode
    shader
      ..setFloat(0, amplitude)
      ..setFloat(1, wavelength)
      ..setFloat(2, bias)
      ..setFloat(3, seed.toDouble())
      ..setFloat(4, size.width)
      ..setFloat(5, size.height)
      ..setFloat(6, islandRadius)
      ..setFloat(7, 1.0) // Detection mode
      ..setFloat(8, threshold); // Detection threshold

    // Render shader to image
    final ui.Image image = await _renderShaderToImage();

    // Extract coordinates from the image
    final coordinates = await _extractCoordinatesFromImage(image, bias);

    image.dispose();
    return coordinates;
  }

  /// Render shader to image
  Future<ui.Image> _renderShaderToImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(size.width.floor(), size.height.floor());

    picture.dispose();
    return image;
  }

  /// Extract coordinates from rendered image with bias-aware smoothing
  Future<List<Offset>> _extractCoordinatesFromImage(
      ui.Image image, double bias) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];

    final pixels = byteData.buffer.asUint8List();
    final coordinates = <Offset>[];

    // Process each pixel
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixelIndex = (y * image.width + x) * 4;

        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];
        final a = pixels[pixelIndex + 3];

        // Skip black pixels (no edge detected)
        if (r == 0 && g == 0 && b == 0 && a == 0) continue;

        // Decode coordinate from color channels
        final decodedX = _decodeCoordinate(r, g) * size.width;
        final decodedY = _decodeCoordinate(b, a) * size.height;

        coordinates.add(Offset(decodedX, decodedY));
      }
    }

    // Sort coordinates to form a proper contour with bias-adaptive smoothing
    return _sortCoordinatesIntoContour(coordinates, bias);
  }

  /// Decode coordinate from two color channels
  double _decodeCoordinate(int high, int low) {
    return (high + low / 255.0) / 255.0;
  }

  /// Sort coordinates with bias-adaptive smoothing
  List<Offset> _sortCoordinatesIntoContour(
      List<Offset> coordinates, double bias) {
    if (coordinates.length < 3) return coordinates;

    // Find center point
    final center = coordinates.fold<Offset>(
          Offset.zero,
          (prev, point) => prev + point,
        ) /
        coordinates.length.toDouble();

    // Sort by angle from center
    coordinates.sort((a, b) {
      final angleA = (a - center).direction;
      final angleB = (b - center).direction;
      return angleA.compareTo(angleB);
    });

    // Apply adaptive smoothing based on bias
    // Lower bias = more jagged terrain = more smoothing needed
    int smoothingLevel = bias < 0.0 ? 3 : (bias < 0.3 ? 2 : 1);
    return _smoothCoordinates(coordinates, smoothingLevel);
  }

  /// Smooth coordinates with adjustable level
  List<Offset> _smoothCoordinates(
      List<Offset> coordinates, int smoothingLevel) {
    if (coordinates.length < 5 || smoothingLevel <= 0) return coordinates;

    List<Offset> result = coordinates;

    // Apply multiple passes of smoothing for higher levels
    for (int pass = 0; pass < smoothingLevel; pass++) {
      List<Offset> smoothed = [];
      int windowSize = 1 + pass; // Increase window size each pass

      for (int i = 0; i < result.length; i++) {
        double sumX = 0;
        double sumY = 0;
        int count = 0;

        // Average with neighboring points
        for (int j = -windowSize; j <= windowSize; j++) {
          int idx = (i + j + result.length) % result.length;
          sumX += result[idx].dx;
          sumY += result[idx].dy;
          count++;
        }

        smoothed.add(Offset(sumX / count, sumY / count));
      }

      result = smoothed;
    }

    return result;
  }
}
