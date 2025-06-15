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

class IslandGame extends FlameGame
    with HasCollisionDetection, TapDetector, PanDetector {
  double amplitude;
  double wavelength;
  double bias;
  int seed;
  Vector2 gameSize;
  double islandRadius;
  bool showPerimeter;

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

  // Callback to notify providers when unit counts change
  void Function()? onUnitCountsChanged;

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
    required bool showPerimeter,
  }) {
    this.amplitude = amplitude;
    this.wavelength = wavelength;
    this.bias = bias;
    this.seed = seed;
    this.islandRadius = islandRadius;
    this.showPerimeter = showPerimeter;
    if (_isLoaded && _island.isMounted) {
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );
      _island.showPerimeter = showPerimeter;
    }
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);
    gameSize = newSize;
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
      _island.showPerimeter = showPerimeter;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isLoaded && _island.isMounted) {
      _island.showPerimeter = showPerimeter;
    }

    processGameRules();

    // Force UI updates every frame to ensure HUD reactivity
    if (onUnitCountsChanged != null) {
      onUnitCountsChanged!();
    }
  }
  
  // Toggle topographic map visibility without affecting units
  void toggleTopographicMap(bool show) {
    showPerimeter = show;
    if (_isLoaded && _island.isMounted) {
      _island.showPerimeter = show;
    }
  }

  @override
  void render(Canvas canvas) {
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

  void _clearSelection() {
    for (final unit in _selectedUnits) {
      unit.setSelected(false);
    }
    _selectedUnits.clear();
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

    for (final unit in _units) {
      // Only select units of the player's team
      if (unit.model.health > 0 &&
          (playerTeam == null || unit.model.team == playerTeam) &&
          unit.position.x >= minX &&
          unit.position.x <= maxX &&
          unit.position.y >= minY &&
          unit.position.y <= maxY) {
        unit.setSelected(true);
        _selectedUnits.add(unit);
      }
    }

    debugPrint('Selected ${_selectedUnits.length} units');
  }

  void _moveSelectedUnits(Vector2 target) {
    if (_selectedUnits.isEmpty) return;

    for (final unit in _selectedUnits) {
      if (isOnLand(target)) {
        // Use the setTargetPosition method to properly handle redirection
        unit.setTargetPosition(target);
        // Deselect the unit after setting its target
        unit.setSelected(false);
        debugPrint(
            'Moving ${unit.model.type.name} to $target (distance: ${unit.model.position.distanceTo(target).toStringAsFixed(1)})');
      }
    }
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
    
    // Use these points as spawn locations based on team
    Vector2 spawnPosition = team == Team.blue 
        ? Vector2(northPoint.dx, northPoint.dy + 20) // Slightly inside from north tip
        : Vector2(southPoint.dx, southPoint.dy - 20); // Slightly inside from south tip
    
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
    _selectionStart = info.eventPosition.global;
    _selectionEnd = _selectionStart;
    _isDragging = true;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_isDragging) {
      _selectionEnd = info.eventPosition.global;
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

  @override
  bool onTapDown(TapDownInfo info) {
    // If units are selected, move them to the tapped position
    if (_selectedUnits.isNotEmpty) {
      _moveSelectedUnits(info.eventPosition.global);
      // Clear selection after moving units
      _clearSelection();
    }
    // Removed automatic unit spawning on tap
    return true;
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