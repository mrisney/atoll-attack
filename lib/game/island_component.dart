import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/island_model.dart';
import '../models/terrain_rules.dart';
import '../constants/game_config.dart';

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
    // Apply additional smoothing if enabled in config
    int effectiveSmoothingLevel = kSmoothContours
        ? smoothingLevel + kContourSmoothingLevel
        : smoothingLevel;

    if (coordinates.length < 5 || effectiveSmoothingLevel <= 0) {
      return coordinates;
    }

    List<Offset> result = coordinates;
    for (int pass = 0; pass < effectiveSmoothingLevel; pass++) {
      List<Offset> smoothed = [];
      int windowSize = 1 + pass % 3; // Keep window size reasonable
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
  Map<String, List<Offset>> _shaderContours = {};

  // ==== NEW: Camera and view uniforms ====
  double cameraX = 0;
  double cameraY = 0;
  double viewW = 1;
  double viewH = 1;
  double resolutionX = 1;
  double resolutionY = 1;

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
    // Initialize resolution to match gameSize at startup
    resolutionX = gameSize.x;
    resolutionY = gameSize.y;
    // Default camera to show full world
    cameraX = 0;
    cameraY = 0;
    viewW = gameSize.x;
    viewH = gameSize.y;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadShader();
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
    radius = gameSize.x * 0.3 * islandRadius;
    size = gameSize;
    position = gameSize / 2;
    // Optionally: updateResolution(gameSize.x, gameSize.y);
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
      _drawPerimeter(canvas);
      _drawGridOnLand(canvas);
    }

    final apex = _model?.getApex();
    if (apex != null) {
      final outerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final innerPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      canvas.drawCircle(apex, 8, innerPaint);
      canvas.drawCircle(apex, 8, outerPaint);

      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 3,
            color: Colors.black,
          ),
        ],
      );

      final textSpan = TextSpan(text: "APEX", style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          apex.dx - textPainter.width / 2,
          apex.dy - 25,
        ),
      );
    }
  }

  // ==== REVISED: Set all uniforms for the new island_water.frag ====
  void _renderShaderIsland(Canvas canvas) {
    shader!
      ..setFloat(0, amplitude)
      ..setFloat(1, wavelength)
      ..setFloat(2, bias)
      ..setFloat(3, seed.toDouble())
      ..setFloat(4, resolutionX) // u_resolution_x
      ..setFloat(5, resolutionY) // u_resolution_y
      ..setFloat(6, islandRadius)
      ..setFloat(7, 0.0) // mode: normal render
      ..setFloat(8, 0.0) // detection threshold
      ..setFloat(9, cameraX) // u_camera_x
      ..setFloat(10, cameraY) // u_camera_y
      ..setFloat(11, viewW) // u_view_w
      ..setFloat(12, viewH); // u_view_h

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, resolutionX, resolutionY),
      paint,
    );
  }

  void _renderFallback(Canvas canvas) {
    final paint = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  /// Draw grid points only on land (inside coastline)
  void _drawGridOnLand(Canvas canvas) {
    // ... UNCHANGED ...
    if (_model == null || !kShowGrid) return;

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

  void _drawPerimeter(Canvas canvas) {
    // ... UNCHANGED ...
    final devicePixelRatio = ui.window.devicePixelRatio;
    final scaleFactor = devicePixelRatio > 2.5 ? 1.0 / devicePixelRatio : 1.0;
    final terrainRules = _model?.rules ?? const TerrainRules();
    final sortedKeys = ['highland', 'midland', 'shallow', 'coastline'];

    for (final key in sortedKeys) {
      final points = _shaderContours[key];
      if (points == null || points.length < 3) continue;
      List<Offset> scaledPoints = points;
      if (scaleFactor != 1.0) {
        scaledPoints = points
            .map((p) => Offset(p.dx * scaleFactor, p.dy * scaleFactor))
            .toList();
      }
      final fillPaint = Paint()
        ..color = terrainRules.getContourColor(key).withOpacity(0.2)
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = terrainRules.getContourColor(key)
        ..strokeWidth = terrainRules.getStrokeWidth(key)
        ..style = PaintingStyle.stroke;

      final path = Path();
      if (scaledPoints.isNotEmpty) {
        path.moveTo(scaledPoints[0].dx, scaledPoints[0].dy);
        for (int i = 1; i < scaledPoints.length; i++) {
          path.lineTo(scaledPoints[i].dx, scaledPoints[i].dy);
        }
        path.close();
      }
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      if (kShowElevationLabels && key != 'coastline') {
        final elevation = terrainRules.elevationLabels[key];
        final textStyle = TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        );
        final numLabels = key == 'highland' ? 1 : 2;
        final step = scaledPoints.length ~/ (numLabels + 1);

        for (int i = 1; i <= numLabels; i++) {
          final index = i * step;
          if (index < scaledPoints.length) {
            final position = scaledPoints[index];
            final textSpan = TextSpan(text: '$elevation m', style: textStyle);
            final textPainter = TextPainter(
              text: textSpan,
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            final bgRect = Rect.fromCenter(
              center: position,
              width: textPainter.width + 6,
              height: textPainter.height + 4,
            );
            canvas.drawRect(
              bgRect,
              Paint()..color = Colors.white.withOpacity(0.7),
            );
            textPainter.paint(
              canvas,
              Offset(
                position.dx - textPainter.width / 2,
                position.dy - textPainter.height / 2,
              ),
            );
          }
        }
      }
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

  // ==== NEW: Camera/viewport update API ====
  void updateCameraRegion({
    required double cameraX,
    required double cameraY,
    required double viewW,
    required double viewH,
  }) {
    this.cameraX = cameraX;
    this.cameraY = cameraY;
    this.viewW = viewW;
    this.viewH = viewH;
  }

  void updateResolution(double width, double height) {
    resolutionX = width;
    resolutionY = height;
  }

  // ==== UNCHANGED: Model APIs ====
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
    return _model!.getElevationAt(Offset(worldPosition.x, worldPosition.y));
  }

  Vector2 toCentered(Vector2 worldPosition) {
    double minRes = math.min(size.x, size.y);
    double cx = (worldPosition.x - size.x / 2) / (0.5 * minRes);
    double cy = (worldPosition.y - size.y / 2) / (0.5 * minRes);
    return Vector2(cx, cy);
  }

  Future<void> refreshContours() async {
    await _extractShaderContours();
    _buildIslandModel();
  }

  List<GridCell> getIslandGrid() => _model?.getGridCells() ?? [];
  Offset? getApexPosition() {
    if (_model == null) return null;
    return _model!.getApex();
  }

  Map<String, List<Offset>> getContours() => _model?.getContours() ?? {};
  List<Offset> getCoastline() => _model?.getContour('coastline') ?? [];
  List<Offset> getHighGroundPerimeter() => _model?.getContour('highland') ?? [];
  IslandGridModel? getIslandGridModel() => _model;

  @override
  void update(double dt) {}
}
