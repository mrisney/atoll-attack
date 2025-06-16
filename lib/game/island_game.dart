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
    with HasCollisionDetection, TapDetector, PanDetector, ScrollDetector, ScaleDetector {
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  bool showPerimeter;
  
  // Simple zoom properties
  double zoomLevel = 1.0;
  final double minZoom = 0.5;
  final double maxZoom = 2.0;

  late IslandComponent _island;
  bool _isLoaded = false;
  final List<UnitComponent> _units = [];
  final List<UnitComponent> _selectedUnits = [];
  bool _victoryAchieved = false;
  bool useAssets = false;

  // Unit limit tracking with proper counts per type
  static const int maxCaptainsPerTeam = kMaxCaptainsPerTeam;
  static const int maxArchersPerTeam = kMaxArchersPerTeam;
  static const int maxSwordsmenPerTeam = kMaxSwordsmenPerTeam;

  int _blueCaptainsSpawned = 0;
  int _blueArchersSpawned = 0;
  int _blueSwordsmenSpawned = 0;
  int _redCaptainsSpawned = 0;
  int _redArchersSpawned = 0;
  int _redSwordsmenSpawned = 0;

  // Rules engine properties
  GameState _currentGameState = GameState();
  double _lastRulesUpdate = 0.0;
  static const double _rulesUpdateInterval = kRulesUpdateInterval;
  
  // Track actual units remaining for each team
  int _blueUnitsRemaining = kTotalUnitsPerTeam;
  int _redUnitsRemaining = kTotalUnitsPerTeam;

  // Callbacks to notify providers when unit counts change or unit info should be shown
  void Function()? onUnitCountsChanged;
  void Function(String info)? onShowUnitInfo;

  // Selection box properties
  Vector2? _selectionStart;
  Vector2? _selectionEnd;
  bool _isDragging = false;
  final Paint _selectionPaint = Paint()
    ..color = Colors.white.withOpacity(0.3)
    ..style = PaintingStyle.fill;
  final Paint _selectionBorderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
    
  // Destination marker properties
  Vector2? _destinationMarker;
  double _markerOpacity = 0.7;
  double _markerPulseScale = 1.0;
  double _markerTimer = 0.0;

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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize responsive size utility with game size
    ResponsiveSizeUtil().init(Size(gameSize.x, gameSize.y));
    
    _island = IslandComponent(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      gameSize: gameSize,
      islandRadius: islandRadius,
      showPerimeter: showPerimeter,
    );
    _island.position = gameSize / 2;
    add(_island);
    
    // Reset game rules
    GameRules.resetGame();
    _blueUnitsRemaining = kTotalUnitsPerTeam;
    _redUnitsRemaining = kTotalUnitsPerTeam;

    _isLoaded = true;
    debugPrint('Island game loaded with size: ${gameSize.x}x${gameSize.y}');
  }

  void updateParameters({
    required double amplitude,
    required double wavelength,
    required double bias,
    required int seed,
    required double islandRadius,
    required bool showPerimeter, // Parameter kept for backward compatibility
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    this.islandRadius = islandRadius;
    this.showPerimeter = false; // Always set to false regardless of parameter
    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );
      _island.showPerimeter = false; // Always set to false
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    gameSize = newSize;
    
    // Update responsive size utility with new game size
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
      _island.showPerimeter = false; // Always set to false
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isLoaded && _island.isMounted) {
      _island.showPerimeter = false; // Always keep perimeter off
    }

    processGameRules();
    
    // Update destination marker
    _updateDestinationMarker(dt);

    // Force UI updates every frame to ensure HUD reactivity
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
    }
  }
  
  void _updateDestinationMarker(double dt) {
    if (_destinationMarker != null) {
      _markerTimer += dt;
      
      // Pulse effect - more pronounced
      _markerPulseScale = 1.0 + 0.5 * math.sin(_markerTimer * 4);
      
      // Fade out over time, but more slowly
      _markerOpacity -= dt * 0.05;
      
      // Check if any units are still moving to this destination
      bool unitsStillMoving = false;
      for (final unit in _units) {
        if (unit.model.targetPosition != null) {
          final distance = (_destinationMarker! - unit.model.targetPosition!).length;
          if (distance < 20) { // Increased threshold
            unitsStillMoving = true;
            break;
          }
        }
      }
      
      // Remove marker if it's faded out or no units are moving to it
      if (_markerOpacity <= 0 || !unitsStillMoving) {
        _destinationMarker = null;
      }
    }
  }
  
  // Toggle topographic map visibility - deprecated
  void toggleApexMarker(bool show) {
    // No-op - feature deprecated
  }

  @override
  void render(Canvas canvas) {
    // Apply zoom transformation
    canvas.save();
    canvas.scale(zoomLevel);
    
    super.render(canvas);

    // Draw selection box
    if (_isDragging && _selectionStart != null && _selectionEnd != null) {
      final rect = Rect.fromPoints(
        Offset(_selectionStart!.x, _selectionStart!.y),
        Offset(_selectionEnd!.x, _selectionEnd!.y),
      );

      canvas.drawRect(rect, _selectionPaint);
      canvas.drawRect(rect, _selectionBorderPaint);
    }
    
    // Restore canvas
    canvas.restore();
    
    // Draw destination marker
    if (_destinationMarker != null) {
      final markerPaint = Paint()
        ..color = Colors.white.withOpacity(_markerOpacity)
        ..style = PaintingStyle.fill;
      
      final markerBorderPaint = Paint()
        ..color = Colors.white.withOpacity(_markerOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Draw pulsing circle
      canvas.drawCircle(
        Offset(_destinationMarker!.x, _destinationMarker!.y),
        10 * _markerPulseScale, // Larger radius
        markerPaint
      );
      
      canvas.drawCircle(
        Offset(_destinationMarker!.x, _destinationMarker!.y),
        10 * _markerPulseScale, // Larger radius
        markerBorderPaint
      );
      
      // Draw crosshair lines for better visibility
      final crosshairPaint = Paint()
        ..color = Colors.white.withOpacity(_markerOpacity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      // Horizontal line
      canvas.drawLine(
        Offset(_destinationMarker!.x - 15, _destinationMarker!.y),
        Offset(_destinationMarker!.x + 15, _destinationMarker!.y),
        crosshairPaint
      );
      
      // Vertical line
      canvas.drawLine(
        Offset(_destinationMarker!.x, _destinationMarker!.y - 15),
        Offset(_destinationMarker!.x, _destinationMarker!.y + 15),
        crosshairPaint
      );
    }
  }

  double getElevationAt(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getElevationAt(worldPosition);
    }
    return 0.0;
  }

  bool isOnLand(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.isOnLand(worldPosition);
    }
    return false;
  }

  double getMovementSpeedMultiplier(Vector2 worldPosition) {
    if (_isLoaded && _island.isMounted) {
      return _island.getMovementSpeedMultiplier(worldPosition);
    }
    return 1.0;
  }

  Offset? getIslandApex() {
    if (_isLoaded && _island.isMounted) {
      return _island.getApexPosition();
    }
    return null;
  }

  List<Offset> getCoastline() {
    if (_isLoaded && _island.isMounted) {
      return _island.getCoastline();
    }
    return [];
  }

  List<UnitComponent> getAllUnits() {
    return _units;
  }

  PathfindingService? _pathfindingService;

  PathfindingService? getPathfindingService() {
    if (_pathfindingService == null && _isLoaded && _island.isMounted) {
      final islandModel = _island.getIslandGridModel();
      if (islandModel != null) {
        _pathfindingService = PathfindingService(islandModel);
      }
    }
    return _pathfindingService;
  }

  void captainReachedApex(UnitComponent captain) {
    // Only set victory if captain plants flag at apex
    if (!_victoryAchieved && captain.model.hasPlantedFlag) {
      _victoryAchieved = true;
      debugPrint('Victory! Captain has planted the flag at the apex!');
    }
  }

  bool isVictoryAchieved() {
    // Victory is achieved when all opposing units are eliminated or captain plants flag
    if (_victoryAchieved) return true;
    
    // Check if one team has been completely eliminated
    int blueCount = _units.where((u) => u.model.team == Team.blue && u.model.health > 0).length;
    int redCount = _units.where((u) => u.model.team == Team.red && u.model.health > 0).length;
    
    // Only declare victory if both teams had units and one is now eliminated
    if ((blueCount > 0 && redCount == 0 && redUnitsRemaining == 0) || 
        (redCount > 0 && blueCount == 0 && blueUnitsRemaining == 0)) {
      _victoryAchieved = true;
      return true;
    }
    
    return false;
  }

  void clearSelection() {
    for (final unit in _selectedUnits) {
      unit.setSelected(false);
    }
    _selectedUnits.clear();
    
    // Notify UI of the change
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
    }
  }
  
  void _clearSelection() {
    clearSelection();
  }

  void _selectUnitsInBox(Vector2 start, Vector2 end) {
    _clearSelection();

    final minX = math.min(start.x, end.x);
    final maxX = math.max(start.x, end.x);
    final minY = math.min(start.y, end.y);
    final maxY = math.max(start.y, end.y);

    // Determine which team the player is controlling (last spawned unit's team)
    Team? playerTeam;
    if (_units.isNotEmpty) {
      playerTeam = _units.last.model.team;
    }

    // Make selection box more generous on mobile devices
    final selectionBuffer = 10.0; // Extra pixels to make selection easier

    for (final unit in _units) {
      // Only select units of the player's team
      if (unit.model.health > 0 &&
          (playerTeam == null || unit.model.team == playerTeam) &&
          unit.position.x >= minX - selectionBuffer &&
          unit.position.x <= maxX + selectionBuffer &&
          unit.position.y >= minY - selectionBuffer &&
          unit.position.y <= maxY + selectionBuffer) {
        unit.setSelected(true);
        _selectedUnits.add(unit);
      }
    }

    // If we selected units, show a visual feedback and trigger UI update
    if (_selectedUnits.isNotEmpty) {
      // Flash the selection box briefly
      _selectionPaint.color = Colors.white.withOpacity(0.5);
      Future.delayed(const Duration(milliseconds: 100), () {
        _selectionPaint.color = Colors.white.withOpacity(0.3);
      });
      
      // Trigger UI update to show selected units info
      if (onUnitCountsChanged != null) {
        onUnitCountsChanged!();
      }
    }

    debugPrint('Selected ${_selectedUnits.length} units');
  }

  void _moveSelectedUnits(Vector2 target) {
    if (_selectedUnits.isEmpty) return;
    
    // Always create a destination marker regardless of land check
    _createDestinationMarker(target);

    for (final unit in _selectedUnits) {
      // Always allow movement regardless of land check
      // Use the setTargetPosition method to properly handle redirection
      unit.setTargetPosition(target);
      debugPrint(
          'Moving ${unit.model.type.name} to $target (distance: ${unit.model.position.distanceTo(target).toStringAsFixed(1)})');
    }
    
    // Don't automatically clear selection to allow for multiple commands
    // The selection state will be reset in onTapDown when needed
  }

  void checkVictoryConditions() {
    final unitModels = _units.map((u) => u.model).toList();
    final victoryState = GameRules.checkVictoryConditions(unitModels, unitModels);
    
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

  void processGameRules() {
    _lastRulesUpdate += 1 / 60;

    if (_lastRulesUpdate >= _rulesUpdateInterval) {
      _lastRulesUpdate = 0.0;

      final unitModels = _units.map((u) => u.model).toList();
      _currentGameState = GameRules.processRules(
        unitModels,
        apex: getIslandApex(),
      );
      
      // Update our remaining unit counts from the game state
      _blueUnitsRemaining = _currentGameState.blueUnitsRemaining;
      _redUnitsRemaining = _currentGameState.redUnitsRemaining;

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
              forceRefreshUnitCounts(); // Refresh after actual removal
            }
          });
        }
      }

      if (unitsRemoved) {
        forceRefreshUnitCounts();
      }

      if (_currentGameState.victoryState.hasWinner && !_victoryAchieved) {
        _victoryAchieved = true;
        final winner = _currentGameState.victoryState.winner;
        final reason = _currentGameState.victoryState.reason;

        String reasonText = switch (reason) {
          VictoryReason.flagCapture => 'Flag captured at the apex!',
          VictoryReason.elimination => 'All enemy units eliminated!',
          VictoryReason.captainElimination => 'Enemy captain eliminated!',
          _ => 'Victory achieved!',
        };

        debugPrint(
            '${winner == Team.blue ? "Blue" : "Red"} team wins! $reasonText');
        forceRefreshUnitCounts(); // Refresh on victory
      }
    }
  }

  void _decrementUnitCount(Team team, UnitType type) {
    // Decrement specific unit type count
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
      
      // Decrement total units remaining
      GameRules.decrementUnitsRemaining(team);
      _blueUnitsRemaining = GameRules.getUnitsRemaining(team);
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
      
      // Decrement total units remaining
      GameRules.decrementUnitsRemaining(team);
      _redUnitsRemaining = GameRules.getUnitsRemaining(team);
    }

    // Force refresh after decrementing
    forceRefreshUnitCounts();
  }

  // Add a method to force refresh unit counts
  void forceRefreshUnitCounts() {
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
    }
  }

  // Getter methods for the HUD - FIXED to calculate from actual units
  int get blueUnitCount {
    final count = _units
        .where((u) => u.model.team == Team.blue && u.model.health > 0)
        .length;
    return count;
  }

  int get redUnitCount {
    final count = _units
        .where((u) => u.model.team == Team.red && u.model.health > 0)
        .length;
    return count;
  }

  double get blueHealthPercent {
    final blueUnits = _units
        .where((u) => u.model.team == Team.blue && u.model.health > 0)
        .toList();
    if (blueUnits.isEmpty) return 0.0;

    double totalHealth =
        blueUnits.fold(0.0, (sum, unit) => sum + unit.model.health);
    double maxHealth =
        blueUnits.fold(0.0, (sum, unit) => sum + unit.model.maxHealth);

    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }

  double get redHealthPercent {
    final redUnits = _units
        .where((u) => u.model.team == Team.red && u.model.health > 0)
        .toList();
    if (redUnits.isEmpty) return 0.0;

    double totalHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.health);
    double maxHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.maxHealth);

    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }

  int get blueUnitsRemaining => _blueUnitsRemaining;
  int get redUnitsRemaining => _redUnitsRemaining;

  int get blueCaptainsRemaining => maxCaptainsPerTeam - _blueCaptainsSpawned;
  int get blueArchersRemaining => maxArchersPerTeam - _blueArchersSpawned;
  int get blueSwordsmenRemaining => maxSwordsmenPerTeam - _blueSwordsmenSpawned;
  int get redCaptainsRemaining => maxCaptainsPerTeam - _redCaptainsSpawned;
  int get redArchersRemaining => maxArchersPerTeam - _redArchersSpawned;
  int get redSwordsmenRemaining => maxSwordsmenPerTeam - _redSwordsmenSpawned;

  int get blueUnitsSpawned =>
      _blueCaptainsSpawned + _blueArchersSpawned + _blueSwordsmenSpawned;
  int get redUnitsSpawned =>
      _redCaptainsSpawned + _redArchersSpawned + _redSwordsmenSpawned;

  List<UnitComponent> get selectedUnits => _selectedUnits;

  // Add getter for selectedUnit (for compatibility with game_screen.dart)
  UnitComponent? get selectedUnit =>
      _selectedUnits.isNotEmpty ? _selectedUnits.first : null;

  void spawnSingleUnit(UnitType unitType, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    // Get all unit models for checking captain existence
    final unitModels = _units.map((u) => u.model).toList();
    
    // Use GameRules to check if we can spawn this unit type
    if (!GameRules.canSpawnMoreUnits(team)) {
      debugPrint('${team.name} team has no more units remaining');
      return;
    }
    
    bool canSpawn = false;
    if (team == Team.blue) {
      // Check specific unit type limits
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
      // Check specific unit type limits
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

    final rng = math.Random();
    final apex = getIslandApex();
    if (apex == null) return;

    // Find spawn locations at the northern and southern tips of the island
    List<Offset> coastline = getCoastline();
    if (coastline.isEmpty) {
      debugPrint("No coastline found, using default spawn locations");
      return;
    }
    
    // Find the northernmost and southernmost points on the coastline
    Offset northPoint = coastline.reduce((a, b) => a.dy < b.dy ? a : b);
    Offset southPoint = coastline.reduce((a, b) => a.dy > b.dy ? a : b);
    
    // Use these points as spawn locations based on team, but ensure they're well inside the island
    Vector2 spawnPosition = team == Team.blue 
        ? Vector2(gameSize.x / 2, northPoint.dy + 50) // Blue team at north, well inside island
        : Vector2(gameSize.x / 2, southPoint.dy - 50); // Red team at south, well inside island
    
    // Add some randomness to prevent units from stacking exactly
    double spawnX = spawnPosition.x + (rng.nextDouble() * 60 - 30); // ±30px horizontally
    Vector2 unitPosition = Vector2(spawnX, spawnPosition.y);

    // Always spawn units regardless of land check - fix for spawning issues
    {
        Vector2 toApex = Vector2(apex.dx, apex.dy) - unitPosition;
        toApex.normalize();

        final unitModel = UnitModel(
          id: 'unit_${DateTime.now().millisecondsSinceEpoch}_${team.name}_${unitType.name}',
          type: unitType,
          position: unitPosition,
          team: team,
          velocity: toApex.scaled(8.0), // Slower initial velocity
          isOnLandCallback: isOnLand,
          getTerrainSpeedCallback:
              getMovementSpeedMultiplier, // Add terrain callback
        );

        // Set the target to apex immediately
        unitModel.targetPosition = Vector2(apex.dx, apex.dy);

        final unitComponent = UnitComponent(model: unitModel);
        add(unitComponent);
        _units.add(unitComponent);

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
            "Spawned ${unitType.name} for ${team.name} team at $unitPosition. Remaining: ${_getRemainingForType(team, unitType)}");

        // Force UI refresh after spawning
        forceRefreshUnitCounts();
        return;
    }

    // This code is now unreachable since we removed the land check
  }

  int _getRemainingForType(Team team, UnitType type) {
    if (team == Team.blue) {
      switch (type) {
        case UnitType.captain:
          return blueCaptainsRemaining;
        case UnitType.archer:
          return blueArchersRemaining;
        case UnitType.swordsman:
          return blueSwordsmenRemaining;
      }
    } else {
      switch (type) {
        case UnitType.captain:
          return redCaptainsRemaining;
        case UnitType.archer:
          return redArchersRemaining;
        case UnitType.swordsman:
          return redSwordsmenRemaining;
      }
    }
  }

  // Drag selection implementation with correct event types
  @override
  void onPanStart(DragStartInfo info) {
    // Apply zoom transformation manually
    _selectionStart = Vector2(
      info.eventPosition.global.x / zoomLevel,
      info.eventPosition.global.y / zoomLevel
    );
    _selectionEnd = _selectionStart;
    _isDragging = true;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_isDragging) {
      // Apply zoom transformation manually
      _selectionEnd = Vector2(
        info.eventPosition.global.x / zoomLevel,
        info.eventPosition.global.y / zoomLevel
      );
    }
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (_isDragging && _selectionStart != null && _selectionEnd != null) {
      final distance = (_selectionEnd! - _selectionStart!).length;

      if (distance > 15) {
        // Increased threshold for drag vs click
        // Drag selection
        _selectUnitsInBox(_selectionStart!, _selectionEnd!);
      } else {
        // Single click - check if we have selected units first
        if (_selectedUnits.isNotEmpty) {
          _moveSelectedUnits(_selectionStart!);
          // Clear selection after moving units
          _clearSelection();
        }
        // Removed automatic unit spawning on click
      }
    }

    _isDragging = false;
    _selectionStart = null;
    _selectionEnd = null;
  }
  
  // Zoom and pan methods
  void zoomIn() {
    if (zoomLevel < maxZoom) {
      zoomLevel += 0.25;
      if (zoomLevel > maxZoom) zoomLevel = maxZoom;
    }
  }
  
  void zoomOut() {
    if (zoomLevel > minZoom) {
      zoomLevel -= 0.25;
      if (zoomLevel < minZoom) zoomLevel = minZoom;
    }
  }
  
  void resetZoom() {
    zoomLevel = 1.0;
  }
  
  // Gesture-based zoom and pan handlers
  late double startZoom;
  Vector2? _lastPanPosition;
  
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
    } else {
      // Handle pan - only if not dragging for selection
      if (!_isDragging && _lastPanPosition != null) {
        // Calculate delta from last position for more accurate panning
        final currentPosition = info.eventPosition.global;
        final delta = currentPosition - _lastPanPosition!;
        
        // Apply scaling factor to delta for proper panning at different zoom levels
        final scaledDelta = delta / zoomLevel;
        camera.viewfinder.position += Vector2(-scaledDelta.x, -scaledDelta.y);
        
        // Update last position
        _lastPanPosition = currentPosition.clone();
      }
    }
  }
  
  @override
  void onScroll(PointerScrollInfo info) {
    const zoomPerScrollUnit = 0.05;
    zoomLevel += info.scrollDelta.global.y.sign * -zoomPerScrollUnit;
    zoomLevel = zoomLevel.clamp(minZoom, maxZoom);
  }

  // Store last tap position for unit info
  Vector2 _lastTapPosition = Vector2.zero();
  DateTime _lastTapTime = DateTime.now();
  
  @override
  bool onTapDown(TapDownInfo info) {
    _lastTapPosition = info.eventPosition.global;
    
    // Check for double tap to zoom
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 300) {
      // Double tap detected - toggle zoom
      if (zoomLevel > 1.0) {
        zoomLevel = 1.0; // Reset to normal
      } else {
        zoomLevel = 1.75; // Zoom in
      }
      _lastTapTime = DateTime.now().subtract(const Duration(milliseconds: 500)); // Prevent triple tap
      return true;
    }
    _lastTapTime = now;
    
    // Apply zoom transformation manually
    Vector2 worldPos = Vector2(
      _lastTapPosition.x / zoomLevel,
      _lastTapPosition.y / zoomLevel
    );
    
    // Check if we tapped on a unit first
    final tappedUnit = _findUnitAtPosition(worldPos);
    if (tappedUnit != null) {
      // Show unit information
      tappedUnit.showUnitInfo();
      // Select the unit if it's not already selected
      if (!tappedUnit.model.isSelected) {
        _clearSelection();
        tappedUnit.setSelected(true);
        _selectedUnits.add(tappedUnit);
      }
      return true;
    }
    
    // If units are selected, move them to the tapped position
    if (_selectedUnits.isNotEmpty) {
      _moveSelectedUnits(worldPos);
      // Reset selection state after giving movement command
      // This allows the player to select other units immediately
    } else {
      // If no units are selected and we didn't tap on a unit,
      // ensure selection state is cleared
      _clearSelection();
    }
    return true;
  }
  
  // Find a unit at the given position
  UnitComponent? _findUnitAtPosition(Vector2 position) {
    if (position == Vector2.zero()) return null;
    
    for (final unit in _units) {
      if (unit.containsPoint(position)) {
        return unit;
      }
    }
    return null;
  }
  
  // Create a destination marker at the given position
  void _createDestinationMarker(Vector2 position) {
    _destinationMarker = position.clone();
    _markerOpacity = 0.9; // Increased opacity for better visibility
    _markerPulseScale = 1.0;
    _markerTimer = 0.0;
    
    // Make the marker stay visible longer
    Future.delayed(const Duration(seconds: 3), () {
      if (_markerOpacity > 0.3) {
        _markerOpacity = 0.3; // Start fading out after 3 seconds
      }
    });
  }
  
  // Selected units info for UI display
  List<Map<String, dynamic>> getSelectedUnitsInfo() {
    List<Map<String, dynamic>> unitsInfo = [];
    
    // If no units are selected, check if we have a tapped unit
    final unitsList = _selectedUnits.isEmpty ? 
        (_findUnitAtPosition(_lastTapPosition) != null ? 
        [_findUnitAtPosition(_lastTapPosition)!] : []) : 
        _selectedUnits;
    
    for (final unit in unitsList) {
      final healthPercent = (unit.model.health / unit.model.maxHealth * 100).toInt();
      final typeStr = unit.model.type.toString().split('.').last;
      final teamStr = unit.model.team.toString().split('.').last;
      
      unitsInfo.add({
        'type': typeStr.toUpperCase(),
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'hasFlag': unit.model.type == UnitType.captain && unit.model.hasPlantedFlag,
        'id': unit.model.id, // Add unique ID for scrolling panel
      });
    }
    
    return unitsInfo;
  }
  
  // Show unit information in the UI
  void showUnitInfo(String info) {
    debugPrint("Unit Info: $info");
    // Pass the info to the UI callback if available
    if (onShowUnitInfo != null) {
      onShowUnitInfo!(info);
    }
    // Trigger UI update to show selected units info
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
    }
  }

  // This method is no longer used - units are spawned from fixed locations
  void spawnUnitsAtPosition(Vector2 position) {
    // Do nothing - units should be spawned from the game controls panel
  }

  // This method is no longer used - units are spawned from fixed locations
  void spawnUnits(int count, Vector2 position, Team team) {
    // Instead of spawning units here, call spawnSingleUnit for each unit type
    if (!_isLoaded || !_island.isMounted) return;
    
    // Check if team has reached total unit limit
    int unitsRemaining = team == Team.blue ? blueUnitsRemaining : redUnitsRemaining;
    if (unitsRemaining <= 0) {
      debugPrint('${team.name} team has reached maximum total units');
      return;
    }
    
    // Just spawn a single unit of the appropriate type
    final unitModels = _units.map((u) => u.model).toList();
    bool hasCaptain = GameRules.hasCaptain(team, unitModels);
    
    if (!hasCaptain) {
      spawnSingleUnit(UnitType.captain, team);
    } else {
      // Alternate between archer and swordsman
      final rng = math.Random();
      spawnSingleUnit(rng.nextBool() ? UnitType.archer : UnitType.swordsman, team);
    }
    
    debugPrint("Spawned units for ${team.name} team. Blue remaining: $blueUnitsRemaining, Red remaining: $redUnitsRemaining");

    // Force UI refresh after spawning
    forceRefreshUnitCounts();
  }
}