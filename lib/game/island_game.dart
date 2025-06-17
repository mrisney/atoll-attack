import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'island_component.dart';
import 'unit_component.dart';
import '../models/unit_model.dart';
import '../rules/game_rules.dart';
import '../services/pathfinding_service.dart';
import '../managers/unit_selection_manager.dart';
import '../constants/game_config.dart';
import 'dart:ui';
import '../utils/responsive_size_util.dart';

class IslandGame extends FlameGame
    with
        HasCollisionDetection,
        TapDetector,
        PanDetector,
        ScrollDetector,
        ScaleDetector {
  // Game configuration
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  bool showPerimeter;

  // Zoom and camera properties
  double zoomLevel = 1.0;
  final double minZoom = 0.3;
  final double maxZoom = 3.0;
  Vector2? _lastPanPosition;
  late double startZoom;

  // Enhanced gesture handling
  bool _isScaling = false;
  bool _isPanning = false;
  Vector2? _scaleStartFocalPoint;
  Vector2? _panStartCameraPosition;

  // Game components
  late IslandComponent _island;
  bool _isLoaded = false;
  final List<UnitComponent> _units = [];
  PathfindingService? _pathfindingService;

  // Game state
  bool _victoryAchieved = false;
  bool useAssets = false;
  GameState _currentGameState = GameState();
  double _lastRulesUpdate = 0.0;
  static const double _rulesUpdateInterval = kRulesUpdateInterval;

  // Unit tracking
  static const int maxCaptainsPerTeam = kMaxCaptainsPerTeam;
  static const int maxArchersPerTeam = kMaxArchersPerTeam;
  static const int maxSwordsmenPerTeam = kMaxSwordsmenPerTeam;

  int _blueCaptainsSpawned = 0;
  int _blueArchersSpawned = 0;
  int _blueSwordsmenSpawned = 0;
  int _redCaptainsSpawned = 0;
  int _redArchersSpawned = 0;
  int _redSwordsmenSpawned = 0;

  int _blueUnitsRemaining = kTotalUnitsPerTeam;
  int _redUnitsRemaining = kTotalUnitsPerTeam;

  // UI interaction
  Vector2? _selectionStart;
  Vector2? _selectionEnd;
  bool _isDragging = false;
  Vector2? _destinationMarker;
  double _markerOpacity = 0.7;
  double _markerPulseScale = 1.0;
  double _markerTimer = 0.0;
  DateTime _lastTapTime = DateTime.now();

  // Unit selection manager
  late UnitSelectionManager _unitSelectionManager;

  // Paint objects
  final Paint _selectionPaint = Paint()
    ..color = Colors.white.withOpacity(0.3)
    ..style = PaintingStyle.fill;
  final Paint _selectionBorderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  // Callbacks
  void Function()? onUnitCountsChanged;
  void Function(String info)? onShowUnitInfo;

  IslandGame({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.seed,
    required this.gameSize,
    required this.islandRadius,
    this.showPerimeter = false,
  }) {
    // Initialize unit selection manager in constructor to avoid late initialization errors
    _unitSelectionManager = UnitSelectionManager(this);
  }

  @override
  Color backgroundColor() => const Color(0xFF1a1a2e);

  // =============================================================================
  // INITIALIZATION
  // =============================================================================

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Set game size using actual screen pixels (not ScreenUtil)
    gameSize = Vector2(size.x, size.y);

    // Initialize responsive size utility with actual game size
    ResponsiveSizeUtil().init(Size(gameSize.x, gameSize.y));

    // Create and add island
    _island = IslandComponent(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      gameSize: gameSize,
      islandRadius: islandRadius,
      showPerimeter: false, // Always false
    );
    _island.position = gameSize / 2;
    add(_island);

    // Initialize game state
    GameRules.resetGame();
    _blueUnitsRemaining = kTotalUnitsPerTeam;
    _redUnitsRemaining = kTotalUnitsPerTeam;

    _isLoaded = true;
    debugPrint('Island game loaded with size: ${gameSize.x}x${gameSize.y}');
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    gameSize = newSize;

    ResponsiveSizeUtil().init(Size(newSize.x, newSize.y));

    if (_isLoaded && _island.isMounted) {
      _island.gameSize = newSize;
      _island.position = newSize / 2;
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );
    }
  }

  void updateParameters({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required double islandRadius,
    required bool showPerimeter,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    this.islandRadius = islandRadius;
    this.showPerimeter = false; // Always false

    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );
    }
  }

  // =============================================================================
  // COORDINATE SYSTEM
  // =============================================================================

  /// Convert screen tap position to game world coordinates
  Vector2 screenToWorldPosition(Vector2 screenPosition) {
    // Only apply zoom and camera transformations
    // ScreenUtil scaling is handled at Flutter widget level
    final worldX = screenPosition.x / zoomLevel + camera.viewfinder.position.x;
    final worldY = screenPosition.y / zoomLevel + camera.viewfinder.position.y;
    return Vector2(worldX, worldY);
  }

  /// Convert world position to screen coordinates
  Vector2 worldToScreenPosition(Vector2 worldPosition) {
    final screenX =
        (worldPosition.x - camera.viewfinder.position.x) * zoomLevel;
    final screenY =
        (worldPosition.y - camera.viewfinder.position.y) * zoomLevel;
    return Vector2(screenX, screenY);
  }

  // =============================================================================
  // INPUT HANDLING
  // =============================================================================

  @override
  bool onTapDown(TapDownInfo info) {
    final screenPos = info.eventPosition.global;
    final worldPos = screenToWorldPosition(screenPos);

    debugPrint('Tap - Screen: $screenPos, World: $worldPos, Zoom: $zoomLevel');

    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 300) {
      // Double-tap to zoom in or reset
      final newZoom = zoomLevel > 1.0 ? 1.0 : 1.75;

      // --- Center view on tap point ---
      // Compute the offset so that tap point stays at the center after zoom
      final tapWorldBefore = screenToWorldPosition(screenPos);
      zoomLevel = newZoom;
      final tapWorldAfter = screenToWorldPosition(screenPos);

      camera.viewfinder.position += (tapWorldBefore - tapWorldAfter);

      _lastTapTime = DateTime.now().subtract(const Duration(milliseconds: 500));
      return true;
    }
    _lastTapTime = now;

    // Check for unit tap
    final tappedUnit = _findUnitAtPosition(worldPos);
    if (tappedUnit != null) {
      // Handle unit tap through selection manager
      _unitSelectionManager.handleUnitTap(tappedUnit);
      _notifyUIUpdate();
      return true;
    }

    // Handle tap on empty space
    _unitSelectionManager.handleEmptyTap(worldPos);
    _notifyUIUpdate();

    return true;
  }

  @override
  void onPanStart(DragStartInfo info) {
    _selectionStart = info.eventPosition.global.clone();
    _selectionEnd = _selectionStart;
    _isDragging = true;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_isDragging) {
      _selectionEnd = info.eventPosition.global.clone();
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (_isDragging && _selectionStart != null && _selectionEnd != null) {
      final distance = (_selectionEnd! - _selectionStart!).length;

      if (distance > 15) {
        // Drag selection using selection manager
        _unitSelectionManager.selectUnitsInBox(
            _selectionStart!, _selectionEnd!);
        _notifyUIUpdate();
      } else {
        // Single click movement
        final worldPos = screenToWorldPosition(_selectionStart!);
        if (_unitSelectionManager.hasSelection) {
          _unitSelectionManager.moveSelectedUnits(worldPos);
        }
      }
    }

    _isDragging = false;
    _selectionStart = null;
    _selectionEnd = null;
  }

  double _baseZoom = 1.0;
  Vector2? _lastFocalScreen;
  Vector2? _lastFocalWorld;

  @override
  void onScaleStart(ScaleStartInfo info) {
    _baseZoom = zoomLevel;
    _lastFocalScreen = info.eventPosition.global.clone();
    _lastFocalWorld = screenToWorldPosition(_lastFocalScreen!);
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (info.pointerCount < 2) return;

    double newZoom = (_baseZoom * info.scale.global.y).clamp(minZoom, maxZoom);

    if (_lastFocalScreen != null && _lastFocalWorld != null) {
      zoomLevel = newZoom;
      final newWorldAtFocalScreen = screenToWorldPosition(_lastFocalScreen!);
      camera.viewfinder.position += (_lastFocalWorld! - newWorldAtFocalScreen);
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _lastFocalScreen = null;
    _lastFocalWorld = null;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    const zoomPerScrollUnit = 0.05;
    zoomLevel += info.scrollDelta.global.y.sign * -zoomPerScrollUnit;
    zoomLevel = zoomLevel.clamp(minZoom, maxZoom);
  }

  // =============================================================================
  // UNIT SELECTION AND MOVEMENT
  // =============================================================================

  // This method is now deprecated - use UnitSelectionManager instead
  void _selectUnitsInBox(Vector2 screenStart, Vector2 screenEnd) {
    // Delegate to the unit selection manager
    _unitSelectionManager.selectUnitsInBox(screenStart, screenEnd);
    _notifyUIUpdate();
  }

  void _moveSelectedUnits(Vector2 worldTarget) {
    if (_unitSelectionManager.selectedUnits.isEmpty) return;

    _createDestinationMarker(worldTarget);

    for (final unit in _unitSelectionManager.selectedUnits) {
      unit.setTargetPosition(worldTarget);
      debugPrint('Moving ${unit.model.type.name} to $worldTarget');
    }
  }

  UnitComponent? _findUnitAtPosition(Vector2 worldPosition) {
    for (final unit in _units) {
      if (unit.model.health <= 0) continue;
      final distance = unit.position.distanceTo(worldPosition);
      if (distance <= unit.model.radius + 10) {
        return unit;
      }
    }
    return null;
  }

  void clearSelection() {
    _unitSelectionManager.clearSelection();
    _notifyUIUpdate();
  }

  // =============================================================================
  // DESTINATION MARKER
  // =============================================================================

  void _createDestinationMarker(Vector2 worldPosition) {
    _destinationMarker = worldPosition.clone();
    _markerOpacity = 0.9;
    _markerPulseScale = 1.0;
    _markerTimer = 0.0;

    Future.delayed(const Duration(seconds: 3), () {
      if (_markerOpacity > 0.3) {
        _markerOpacity = 0.3;
      }
    });
  }

  /// Public method to create destination marker (for UnitSelectionManager)
  void createDestinationMarker(Vector2 worldPosition) {
    _createDestinationMarker(worldPosition);
  }

  void _updateDestinationMarker(double dt) {
    if (_destinationMarker != null) {
      _markerTimer += dt;
      _markerPulseScale = 1.0 + 0.5 * math.sin(_markerTimer * 4);
      _markerOpacity -= dt * 0.05;

      // Check if units are still moving to this destination
      bool unitsStillMoving = false;
      for (final unit in _units) {
        if (unit.model.targetPosition != null) {
          final distance =
              (_destinationMarker! - unit.model.targetPosition!).length;
          if (distance < 20) {
            unitsStillMoving = true;
            break;
          }
        }
      }

      if (_markerOpacity <= 0 || !unitsStillMoving) {
        _destinationMarker = null;
      }
    }
  }

  // =============================================================================
  // ZOOM CONTROLS
  // =============================================================================

  void zoomIn() {
    zoomLevel = (zoomLevel + 0.25).clamp(minZoom, maxZoom);
  }

  void zoomOut() {
    zoomLevel = (zoomLevel - 0.25).clamp(minZoom, maxZoom);
  }

  void resetZoom() {
    zoomLevel = 1.0;
    camera.viewfinder.position = Vector2.zero();
  }

  // =============================================================================
  // PAN CONTROLS
  // =============================================================================

  /// Pan the camera in a specific direction
  void panCamera(Vector2 direction) {
    const panSpeed = 50.0;
    final scaledDirection = direction.normalized() * panSpeed / zoomLevel;
    camera.viewfinder.position += scaledDirection;
  }

  /// Pan camera up
  void panUp() {
    panCamera(Vector2(0, -1));
  }

  /// Pan camera down
  void panDown() {
    panCamera(Vector2(0, 1));
  }

  /// Pan camera left
  void panLeft() {
    panCamera(Vector2(-1, 0));
  }

  /// Pan camera right
  void panRight() {
    panCamera(Vector2(1, 0));
  }

  // =============================================================================
  // UNIT SPAWNING
  // =============================================================================

  void spawnSingleUnit(UnitType unitType, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    final unitModels = _units.map((u) => u.model).toList();

    // Check if team can spawn more units
    if (!GameRules.canSpawnMoreUnits(team)) {
      debugPrint('${team.name} team has no more units remaining');
      return;
    }

    // Check specific unit type limits
    bool canSpawn = false;
    if (team == Team.blue) {
      switch (unitType) {
        case UnitType.captain:
          canSpawn = _blueCaptainsSpawned < maxCaptainsPerTeam &&
              !GameRules.hasCaptain(team, unitModels);
        case UnitType.archer:
          canSpawn = _blueArchersSpawned < maxArchersPerTeam;
        case UnitType.swordsman:
          canSpawn = _blueSwordsmenSpawned < maxSwordsmenPerTeam;
      }
    } else {
      switch (unitType) {
        case UnitType.captain:
          canSpawn = _redCaptainsSpawned < maxCaptainsPerTeam &&
              !GameRules.hasCaptain(team, unitModels);
        case UnitType.archer:
          canSpawn = _redArchersSpawned < maxArchersPerTeam;
        case UnitType.swordsman:
          canSpawn = _redSwordsmenSpawned < maxSwordsmenPerTeam;
      }
    }

    if (!canSpawn) {
      debugPrint(
          '${team.name} team has reached maximum ${unitType.name} units');
      return;
    }

    // Find spawn location
    final apex = getIslandApex();
    if (apex == null) return;

    final coastline = getCoastline();
    if (coastline.isEmpty) {
      debugPrint("No coastline found, using default spawn locations");
      return;
    }

    // Find spawn points
    final northPoint = coastline.reduce((a, b) => a.dy < b.dy ? a : b);
    final southPoint = coastline.reduce((a, b) => a.dy > b.dy ? a : b);

    final baseSpawnY =
        team == Team.blue ? northPoint.dy + 50 : southPoint.dy - 50;
    final rng = math.Random();
    final spawnX = gameSize.x / 2 + (rng.nextDouble() * 60 - 30);
    final unitPosition = Vector2(spawnX, baseSpawnY);

    // Create unit
    final toApex = (Vector2(apex.dx, apex.dy) - unitPosition)..normalize();
    final unitModel = UnitModel(
      id: 'unit_${DateTime.now().millisecondsSinceEpoch}_${team.name}_${unitType.name}',
      type: unitType,
      position: unitPosition,
      team: team,
      velocity: toApex.scaled(8.0),
      isOnLandCallback: isOnLand,
      getTerrainSpeedCallback: getMovementSpeedMultiplier,
    );

    unitModel.targetPosition = Vector2(apex.dx, apex.dy);

    final unitComponent = UnitComponent(model: unitModel);
    add(unitComponent);
    _units.add(unitComponent);

    // Update spawn counts
    if (team == Team.blue) {
      switch (unitType) {
        case UnitType.captain:
          _blueCaptainsSpawned++;
        case UnitType.archer:
          _blueArchersSpawned++;
        case UnitType.swordsman:
          _blueSwordsmenSpawned++;
      }
    } else {
      switch (unitType) {
        case UnitType.captain:
          _redCaptainsSpawned++;
        case UnitType.archer:
          _redArchersSpawned++;
        case UnitType.swordsman:
          _redSwordsmenSpawned++;
      }
    }

    debugPrint(
        'Spawned ${unitType.name} for ${team.name} team at $unitPosition');
    _notifyUIUpdate();
  }

  // =============================================================================
  // GAME LOOP
  // =============================================================================

  @override
  void update(double dt) {
    super.update(dt);
    _updateDestinationMarker(dt);
    _processGameRules();
    _notifyUIUpdate();
  }

  void _processGameRules() {
    _lastRulesUpdate += 1 / 60;

    if (_lastRulesUpdate >= _rulesUpdateInterval) {
      _lastRulesUpdate = 0.0;

      final unitModels = _units.map((u) => u.model).toList();
      _currentGameState =
          GameRules.processRules(unitModels, apex: getIslandApex());

      _blueUnitsRemaining = _currentGameState.blueUnitsRemaining;
      _redUnitsRemaining = _currentGameState.redUnitsRemaining;

      // Handle unit removal
      bool unitsRemoved = false;
      for (final unitId in _currentGameState.unitsToRemove) {
        final unitToRemove =
            _units.where((u) => u.model.id == unitId).firstOrNull;
        if (unitToRemove != null) {
          _decrementUnitCount(unitToRemove.model.team, unitToRemove.model.type);

          // If unit is selected, clear it from selection
          if (unitToRemove.model.isSelected) {
            _unitSelectionManager.clearSelection();
          }

          unitToRemove.playDeathAnimation();
          unitsRemoved = true;

          Future.delayed(const Duration(milliseconds: 800), () {
            if (unitToRemove.isMounted) {
              unitToRemove.removeFromParent();
              _units.remove(unitToRemove);
              _notifyUIUpdate();
            }
          });
        }
      }

      if (unitsRemoved) _notifyUIUpdate();

      // Handle victory
      if (_currentGameState.victoryState.hasWinner && !_victoryAchieved) {
        _victoryAchieved = true;
        final winner = _currentGameState.victoryState.winner;
        final reason = _currentGameState.victoryState.reason;

        final reasonText = switch (reason) {
          VictoryReason.flagCapture => 'Flag captured at the apex!',
          VictoryReason.elimination => 'All enemy units eliminated!',
          VictoryReason.captainElimination => 'Enemy captain eliminated!',
          _ => 'Victory achieved!',
        };

        debugPrint(
            '${winner == Team.blue ? "Blue" : "Red"} team wins! $reasonText');
        _notifyUIUpdate();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Apply zoom
    canvas.save();
    canvas.scale(zoomLevel);
    super.render(canvas);
    canvas.restore();

    // Draw selection box (screen coordinates)
    if (_isDragging && _selectionStart != null && _selectionEnd != null) {
      final rect = Rect.fromPoints(
        Offset(_selectionStart!.x, _selectionStart!.y),
        Offset(_selectionEnd!.x, _selectionEnd!.y),
      );
      canvas.drawRect(rect, _selectionPaint);
      canvas.drawRect(rect, _selectionBorderPaint);
    }

    // Draw destination marker (world coordinates converted to screen)
    if (_destinationMarker != null) {
      final screenPos = worldToScreenPosition(_destinationMarker!);
      _drawDestinationMarker(canvas, screenPos);
    }

    // Render attack range indicators
    _unitSelectionManager.renderAttackRange(canvas);
  }

  void _drawDestinationMarker(Canvas canvas, Vector2 screenPos) {
    final markerPaint = Paint()
      ..color = Colors.white.withOpacity(_markerOpacity)
      ..style = PaintingStyle.fill;

    final markerBorderPaint = Paint()
      ..color = Colors.white.withOpacity(_markerOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final crosshairPaint = Paint()
      ..color = Colors.white.withOpacity(_markerOpacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final radius = 10 * _markerPulseScale;
    final center = Offset(screenPos.x, screenPos.y);

    canvas.drawCircle(center, radius, markerPaint);
    canvas.drawCircle(center, radius, markerBorderPaint);
    canvas.drawLine(Offset(center.dx - 15, center.dy),
        Offset(center.dx + 15, center.dy), crosshairPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 15),
        Offset(center.dx, center.dy + 15), crosshairPaint);
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  void _decrementUnitCount(Team team, UnitType type) {
    if (team == Team.blue) {
      switch (type) {
        case UnitType.captain:
          _blueCaptainsSpawned =
              (_blueCaptainsSpawned - 1).clamp(0, maxCaptainsPerTeam);
        case UnitType.archer:
          _blueArchersSpawned =
              (_blueArchersSpawned - 1).clamp(0, maxArchersPerTeam);
        case UnitType.swordsman:
          _blueSwordsmenSpawned =
              (_blueSwordsmenSpawned - 1).clamp(0, maxSwordsmenPerTeam);
      }
    } else {
      switch (type) {
        case UnitType.captain:
          _redCaptainsSpawned =
              (_redCaptainsSpawned - 1).clamp(0, maxCaptainsPerTeam);
        case UnitType.archer:
          _redArchersSpawned =
              (_redArchersSpawned - 1).clamp(0, maxArchersPerTeam);
        case UnitType.swordsman:
          _redSwordsmenSpawned =
              (_redSwordsmenSpawned - 1).clamp(0, maxSwordsmenPerTeam);
      }
    }

    GameRules.decrementUnitsRemaining(team);
    if (team == Team.blue) {
      _blueUnitsRemaining = GameRules.getUnitsRemaining(team);
    } else {
      _redUnitsRemaining = GameRules.getUnitsRemaining(team);
    }

    _notifyUIUpdate();
  }

  void _notifyUIUpdate() {
    try {
      if (onUnitCountsChanged != null) {
        onUnitCountsChanged!();
      }
    } catch (e) {
      // Ignore errors when the notifier is no longer mounted
      debugPrint('Error in _notifyUIUpdate: $e');
    }
  }

  void captainReachedApex(UnitComponent captain) {
    if (!_victoryAchieved && captain.model.hasPlantedFlag) {
      _victoryAchieved = true;
      debugPrint('Victory! Captain has planted the flag at the apex!');
    }
  }

  void showUnitInfo(String info) {
    debugPrint("Unit Info: $info");
    if (onShowUnitInfo != null) {
      onShowUnitInfo!(info);
    }
    _notifyUIUpdate();
  }

  // =============================================================================
  // GETTERS AND ACCESSORS
  // =============================================================================

  double getElevationAt(Vector2 worldPosition) => _isLoaded && _island.isMounted
      ? _island.getElevationAt(worldPosition)
      : 0.0;

  bool isOnLand(Vector2 worldPosition) =>
      _isLoaded && _island.isMounted ? _island.isOnLand(worldPosition) : false;

  double getMovementSpeedMultiplier(Vector2 worldPosition) =>
      _isLoaded && _island.isMounted
          ? _island.getMovementSpeedMultiplier(worldPosition)
          : 1.0;

  Offset? getIslandApex() =>
      _isLoaded && _island.isMounted ? _island.getApexPosition() : null;

  List<Offset> getCoastline() =>
      _isLoaded && _island.isMounted ? _island.getCoastline() : [];

  List<UnitComponent> getAllUnits() => _units;

  PathfindingService? getPathfindingService() {
    if (_pathfindingService == null && _isLoaded && _island.isMounted) {
      final islandModel = _island.getIslandGridModel();
      if (islandModel != null) {
        _pathfindingService = PathfindingService(islandModel);
      }
    }
    return _pathfindingService;
  }

  bool isVictoryAchieved() {
    if (_victoryAchieved) return true;

    final blueCount = _units
        .where((u) => u.model.team == Team.blue && u.model.health > 0)
        .length;
    final redCount = _units
        .where((u) => u.model.team == Team.red && u.model.health > 0)
        .length;

    if ((blueCount > 0 && redCount == 0 && redUnitsRemaining == 0) ||
        (redCount > 0 && blueCount == 0 && blueUnitsRemaining == 0)) {
      _victoryAchieved = true;
      return true;
    }

    return false;
  }

  // Unit count getters
  int get blueUnitCount => _units
      .where((u) => u.model.team == Team.blue && u.model.health > 0)
      .length;
  int get redUnitCount => _units
      .where((u) => u.model.team == Team.red && u.model.health > 0)
      .length;
  int get blueUnitsRemaining => _blueUnitsRemaining;
  int get redUnitsRemaining => _redUnitsRemaining;
  int get blueCaptainsRemaining => maxCaptainsPerTeam - _blueCaptainsSpawned;
  int get blueArchersRemaining => maxArchersPerTeam - _blueArchersSpawned;
  int get blueSwordsmenRemaining => maxSwordsmenPerTeam - _blueSwordsmenSpawned;
  int get redCaptainsRemaining => maxCaptainsPerTeam - _redCaptainsSpawned;
  int get redArchersRemaining => maxArchersPerTeam - _redArchersSpawned;
  int get redSwordsmenRemaining => maxSwordsmenPerTeam - _redSwordsmenSpawned;

  // Spawned unit count getters (for provider compatibility)
  int get blueUnitsSpawned =>
      _blueCaptainsSpawned + _blueArchersSpawned + _blueSwordsmenSpawned;
  int get redUnitsSpawned =>
      _redCaptainsSpawned + _redArchersSpawned + _redSwordsmenSpawned;

  List<UnitComponent> get selectedUnits => _unitSelectionManager.selectedUnits;
  UnitComponent? get selectedUnit =>
      _unitSelectionManager.selectedUnits.isNotEmpty
          ? _unitSelectionManager.selectedUnits.first
          : null;

  double get blueHealthPercent {
    final blueUnits = _units
        .where((u) => u.model.team == Team.blue && u.model.health > 0)
        .toList();
    if (blueUnits.isEmpty) return 0.0;
    final totalHealth =
        blueUnits.fold(0.0, (sum, unit) => sum + unit.model.health);
    final maxHealth =
        blueUnits.fold(0.0, (sum, unit) => sum + unit.model.maxHealth);
    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }

  double get redHealthPercent {
    final redUnits = _units
        .where((u) => u.model.team == Team.red && u.model.health > 0)
        .toList();
    if (redUnits.isEmpty) return 0.0;
    final totalHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.health);
    final maxHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.maxHealth);
    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }

  List<Map<String, dynamic>> getSelectedUnitsInfo() {
    final List<Map<String, dynamic>> unitsInfo = [];
    final selectedUnits = _unitSelectionManager.selectedUnits;

    for (final unit in selectedUnits) {
      final healthPercent =
          (unit.model.health / unit.model.maxHealth * 100).toInt();
      final typeStr = unit.model.type.toString().split('.').last;
      final teamStr = unit.model.team.toString().split('.').last;

      unitsInfo.add({
        'type': typeStr.toUpperCase(),
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'hasFlag':
            unit.model.type == UnitType.captain && unit.model.hasPlantedFlag,
        'id': unit.model.id,
      });
    }

    return unitsInfo;
  }

  // =============================================================================
  // DEPRECATED/LEGACY METHODS (for compatibility)
  // =============================================================================

  void toggleApexMarker(bool show) {
    // No-op - feature deprecated
  }

  void spawnUnitsAtPosition(Vector2 position) {
    // No-op - use spawnSingleUnit instead
  }

  void spawnUnits(int count, Vector2 position, Team team) {
    // Legacy method - use spawnSingleUnit instead
    if (!_isLoaded || !_island.isMounted) return;

    final unitsRemaining =
        team == Team.blue ? blueUnitsRemaining : redUnitsRemaining;
    if (unitsRemaining <= 0) {
      debugPrint('${team.name} team has reached maximum total units');
      return;
    }

    final unitModels = _units.map((u) => u.model).toList();
    final hasCaptain = GameRules.hasCaptain(team, unitModels);

    if (!hasCaptain) {
      spawnSingleUnit(UnitType.captain, team);
    } else {
      final rng = math.Random();
      spawnSingleUnit(
          rng.nextBool() ? UnitType.archer : UnitType.swordsman, team);
    }

    debugPrint(
        "Spawned units for ${team.name} team. Blue remaining: $blueUnitsRemaining, Red remaining: $redUnitsRemaining");
  }

  void forceRefreshUnitCounts() {
    _notifyUIUpdate();
  }

  void checkVictoryConditions() {
    final unitModels = _units.map((u) => u.model).toList();
    final victoryState =
        GameRules.checkVictoryConditions(unitModels, unitModels);

    if (victoryState.hasWinner) {
      _victoryAchieved = true;
      final team = victoryState.winner == Team.blue ? "Blue" : "Red";
      final reason = switch (victoryState.reason) {
        VictoryReason.flagCapture => "flag capture at apex",
        VictoryReason.elimination => "elimination of all enemy units",
        VictoryReason.captainElimination => "elimination of enemy captain",
        _ => "victory",
      };
      debugPrint('$team team wins by $reason!');
    }
  }
}
