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
import '../config.dart';
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
  final double minZoom = 0.5;
  final double maxZoom = 2.0;
  Vector2? _lastPanPosition;
  late double startZoom;

  // Game components
  late IslandComponent _island;
  bool _isLoaded = false;
  final List<UnitComponent> _units = [];
  final List<UnitComponent> _selectedUnits = [];
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
  });

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

    // Handle double tap for zoom
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 300) {
      zoomLevel = zoomLevel > 1.0 ? 1.0 : 1.75;
      _lastTapTime = DateTime.now().subtract(const Duration(milliseconds: 500));
      return true;
    }
    _lastTapTime = now;

    // Check for unit tap
    final tappedUnit = _findUnitAtPosition(worldPos);
    if (tappedUnit != null) {
      tappedUnit.showUnitInfo();
      if (!tappedUnit.model.isSelected) {
        clearSelection();
        tappedUnit.setSelected(true);
        _selectedUnits.add(tappedUnit);
        _notifyUIUpdate();
      }
      return true;
    }

    // Move selected units or clear selection
    if (_selectedUnits.isNotEmpty) {
      _moveSelectedUnits(worldPos);
    } else {
      clearSelection();
    }

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
        // Drag selection
        _selectUnitsInBox(_selectionStart!, _selectionEnd!);
      } else {
        // Single click movement
        final worldPos = screenToWorldPosition(_selectionStart!);
        if (_selectedUnits.isNotEmpty) {
          _moveSelectedUnits(worldPos);
          clearSelection();
        }
      }
    }

    _isDragging = false;
    _selectionStart = null;
    _selectionEnd = null;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    startZoom = zoomLevel;
    _lastPanPosition = info.eventPosition.global.clone();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentScale = info.scale.global;
    if (!currentScale.isIdentity()) {
      // Handle zoom
      zoomLevel = (startZoom * currentScale.y).clamp(minZoom, maxZoom);
    } else if (!_isDragging && _lastPanPosition != null) {
      // Handle pan
      final currentPosition = info.eventPosition.global;
      final delta = currentPosition - _lastPanPosition!;
      final scaledDelta = delta / zoomLevel;
      camera.viewfinder.position += Vector2(-scaledDelta.x, -scaledDelta.y);
      _lastPanPosition = currentPosition.clone();
    }
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

  void _selectUnitsInBox(Vector2 screenStart, Vector2 screenEnd) {
    clearSelection();

    final minX = math.min(screenStart.x, screenEnd.x);
    final maxX = math.max(screenStart.x, screenEnd.x);
    final minY = math.min(screenStart.y, screenEnd.y);
    final maxY = math.max(screenStart.y, screenEnd.y);

    // Get player team (last spawned unit's team)
    Team? playerTeam;
    if (_units.isNotEmpty) {
      playerTeam = _units.last.model.team;
    }

    const selectionBuffer = 10.0;

    for (final unit in _units) {
      if (unit.model.health <= 0) continue;
      if (playerTeam != null && unit.model.team != playerTeam) continue;

      // Convert unit world position to screen position for selection
      final unitScreenPos = worldToScreenPosition(unit.position);

      if (unitScreenPos.x >= minX - selectionBuffer &&
          unitScreenPos.x <= maxX + selectionBuffer &&
          unitScreenPos.y >= minY - selectionBuffer &&
          unitScreenPos.y <= maxY + selectionBuffer) {
        unit.setSelected(true);
        _selectedUnits.add(unit);
      }
    }

    _notifyUIUpdate();
    debugPrint('Selected ${_selectedUnits.length} units');
  }

  void _moveSelectedUnits(Vector2 worldTarget) {
    if (_selectedUnits.isEmpty) return;

    _createDestinationMarker(worldTarget);

    for (final unit in _selectedUnits) {
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
    for (final unit in _selectedUnits) {
      unit.setSelected(false);
    }
    _selectedUnits.clear();
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
          _selectedUnits.remove(unitToRemove);
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
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
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

  List<UnitComponent> get selectedUnits => _selectedUnits;
  UnitComponent? get selectedUnit =>
      _selectedUnits.isNotEmpty ? _selectedUnits.first : null;

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

    for (final unit in _selectedUnits) {
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
