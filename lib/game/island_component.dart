import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:fast_noise/fast_noise.dart' as fn;
import '../models/island_model.dart';

/// Helper class for shader coordinate extraction (unchanged from your working version)
class ShaderCoordinateExtractor {
  final ui.FragmentShader shader;
  final Size size;

  ShaderCoordinateExtractor(this.shader, this.size);

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
      ..setFloat(8, threshold);
    // Render shader to image
    final ui.Image image = await _renderShaderToImage();
    // Extract coordinates from the image
    final coordinates = await _extractCoordinatesFromImage(image, bias);
    image.dispose();
    return coordinates;
  }

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

  Future<List<Offset>> _extractCoordinatesFromImage(
      ui.Image image, double bias) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return [];
    final pixels = byteData.buffer.asUint8List();
    final coordinates = <Offset>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixelIndex = (y * image.width + x) * 4;
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];
        final a = pixels[pixelIndex + 3];
        if (r == 0 && g == 0 && b == 0 && a == 0) continue;
        // Decode coordinate from color channels
        final decodedX = _decodeCoordinate(r, g) * size.width;
        final decodedY = _decodeCoordinate(b, a) * size.height;
        coordinates.add(Offset(decodedX, decodedY));
      }
    }
    return _sortCoordinatesIntoContour(coordinates, bias);
  }

  double _decodeCoordinate(int high, int low) {
    return (high + low / 255.0) / 255.0;
  }

  List<Offset> _sortCoordinatesIntoContour(
      List<Offset> coordinates, double bias) {
    if (coordinates.length < 3) return coordinates;
    final center = coordinates.fold<Offset>(
          Offset.zero,
          (prev, point) => prev + point,
        ) /
        coordinates.length.toDouble();
    coordinates.sort((a, b) {
      final angleA = (a - center).direction;
      final angleB = (b - center).direction;
      return angleA.compareTo(angleB);
    });
    int smoothingLevel = bias < 0.0 ? 3 : (bias < 0.3 ? 2 : 1);
    return _smoothCoordinates(coordinates, smoothingLevel);
  }

  List<Offset> _smoothCoordinates(
      List<Offset> coordinates, int smoothingLevel) {
    if (coordinates.length < 5 || smoothingLevel <= 0) return coordinates;
    List<Offset> result = coordinates;
    for (int pass = 0; pass < smoothingLevel; pass++) {
      List<Offset> smoothed = [];
      int windowSize = 1 + pass;
      for (int i = 0; i < result.length; i++) {
        double sumX = 0;
        double sumY = 0;
        int count = 0;
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

/// Main IslandComponent with rendering logic
class IslandComponent extends PositionComponent {
  // Island model data
  IslandGridModel? _model;

  // Rendering properties
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  double radius;
  bool showPerimeter = false;

  // Shader properties
  ui.FragmentProgram? fragmentProgram;
  ui.FragmentShader? shader;
  bool shaderLoaded = false;
  ShaderCoordinateExtractor? _coordinateExtractor;
  bool _perimeterDirty = true;
  Map<String, List<Offset>> _shaderContours = {};

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
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadShader();
    _perimeterDirty = true;
    await _extractShaderContours();
    _buildIslandModel();
  }

  Future<void> _loadShader() async {
    try {
      fragmentProgram =
          await ui.FragmentProgram.fromAsset('shaders/island_water.frag');
      shader = fragmentProgram!.fragmentShader();
      shaderLoaded = true;
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
    _perimeterDirty = true;
    _extractShaderContours().then((_) => _buildIslandModel());
  }

  void _buildIslandModel() {
    if (_shaderContours.isEmpty) return;

    _model = IslandGridModel.generate(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      size: Size(size.x, size.y),
      islandRadius: islandRadius,
      gridSteps: 40,
      contours: _shaderContours,
    );
  }

  @override
  void render(Canvas canvas) {
    if (shaderLoaded && shader != null) {
      _renderShaderIsland(canvas);
    } else {
      _renderFallback(canvas);
    }
    if (showPerimeter) {
      _drawGridOnLand(canvas);
      _drawPerimeter(canvas);

      // Draw apex (highpoint) only when perimeter is shown
      final apex = _model?.getApex();
      if (apex != null) {
        final paint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;
        canvas.drawCircle(apex, 8, paint);
      }
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
      ..setFloat(7, 0.0)
      ..setFloat(8, 0.0);
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

  /// Draw grid points only on land (inside coastline)
  void _drawGridOnLand(Canvas canvas) {
    if (_model == null) return;

    final Paint gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.19)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (final cell in _model!.getGridCells()) {
      if (cell.isLand) {
        canvas.drawCircle(cell.center, 2.0, gridPaint);
      }
    }
  }

  /// Draw contours (coastline, elevation bands)
  void _drawPerimeter(Canvas canvas) {
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
      final path = Path();
      if (entry.value.isNotEmpty) {
        path.moveTo(entry.value[0].dx, entry.value[0].dy);
        for (int i = 1; i < entry.value.length; i++) {
          path.lineTo(entry.value[i].dx, entry.value[i].dy);
        }
        path.close();
      }
      canvas.drawPath(path, paint);
    }
  }

  /// Extracts contours using shader-based detection (async)
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

  // Public API methods that delegate to the model
  bool isOnLand(Vector2 worldPosition) {
    if (_model == null) return false;
    return _model!.isOnLand(Offset(worldPosition.x, worldPosition.y));
  }

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    if (_model == null) return 0.0;
    return _model!
        .getMovementSpeedMultiplier(Offset(worldPosition.x, worldPosition.y));
  }

  double getElevationAt(Vector2 worldPosition) {
    if (_model == null) return 0.0;

    // Pass world coordinates directly to the model - it will handle the conversion
    return _model!.getElevationAt(Offset(worldPosition.x, worldPosition.y));
  }

  Vector2 toCentered(Vector2 worldPosition) {
    double minRes = math.min(size.x, size.y);
    double cx = (worldPosition.x - size.x / 2) / (0.5 * minRes);
    double cy = (worldPosition.y - size.y / 2) / (0.5 * minRes);
    return Vector2(cx, cy);
  }

  /// Force contour re-extraction and grid rebuild
  Future<void> refreshContours() async {
    _perimeterDirty = true;
    await _extractShaderContours();
    _buildIslandModel();
  }

  // Getters that delegate to the model
  List<GridCell> getIslandGrid() => _model?.getGridCells() ?? [];
  Offset? getApexPosition() => _model?.getApex();
  Map<String, List<Offset>> getContours() => _model?.getContours() ?? {};
  List<Offset> getCoastline() => _model?.getContour('coastline') ?? [];
  List<Offset> getHighGroundPerimeter() => _model?.getContour('highland') ?? [];
  IslandGridModel? getIslandGridModel() => _model;

  @override
  void update(double dt) {}
}
