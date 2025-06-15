import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'island_component.dart';
import 'unit_component.dart';
import '../models/unit_model.dart';
import '../rules/victory_conditions.dart';
import '../rules/combat_rules.dart';
import '../rules/game_rules_engine.dart';
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
        debugPrint(
            'Moving ${unit.model.type.name} to $target (distance: ${unit.model.position.distanceTo(target).toStringAsFixed(1)})');
      }
    }
  }

  void checkVictoryConditions() {
    final unitModels = _units.map((u) => u.model).toList();
    final winningTeam = VictoryConditions.getWinningTeam(unitModels);

    if (winningTeam != null) {
      _victoryAchieved = true;
      debugPrint('${winningTeam == Team.blue ? "Blue" : "Red"} team wins!');
    }
  }

  void processGameRules() {
    _lastRulesUpdate += 1 / 60;

    if (_lastRulesUpdate >= _rulesUpdateInterval) {
      _lastRulesUpdate = 0.0;

      final unitModels = _units.map((u) => u.model).toList();
      _currentGameState = GameRulesEngine.processRules(
        unitModels,
        apex: getIslandApex(),
      );

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

  int get blueUnitsRemaining => kTotalUnitsPerTeam - blueUnitsSpawned;
  int get redUnitsRemaining => kTotalUnitsPerTeam - redUnitsSpawned;

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

    bool canSpawn = false;
    if (team == Team.blue) {
      // Check total units first
      if (blueUnitsSpawned >= kTotalUnitsPerTeam) {
        debugPrint('Blue team has reached maximum total units');
        return;
      }
      
      // Then check specific unit type limits
      switch (unitType) {
        case UnitType.captain:
          canSpawn = _blueCaptainsSpawned < maxCaptainsPerTeam;
        case UnitType.archer:
          canSpawn = _blueArchersSpawned < maxArchersPerTeam;
        case UnitType.swordsman:
          canSpawn = _blueSwordsmenSpawned < maxSwordsmenPerTeam;
      }
    } else {
      // Check total units first
      if (redUnitsSpawned >= kTotalUnitsPerTeam) {
        debugPrint('Red team has reached maximum total units');
        return;
      }
      
      // Then check specific unit type limits
      switch (unitType) {
        case UnitType.captain:
          canSpawn = _redCaptainsSpawned < maxCaptainsPerTeam;
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
    int attempts = 0;

    final coastline = _island.getCoastline();
    if (coastline.isEmpty) return;

    final apex = getIslandApex();
    if (apex == null) return;

    while (attempts < 100) {
      final spawnPoint = coastline[rng.nextInt(coastline.length)];
      Vector2 unitPosition = Vector2(spawnPoint.dx, spawnPoint.dy);

      // Try to spawn slightly inland from coastline for better movement
      if (apex != null) {
        Vector2 toApex = Vector2(apex.dx, apex.dy) - unitPosition;
        toApex.normalize();
        // Move 10-20 pixels inland
        unitPosition += toApex.scaled(10 + rng.nextDouble() * 10);
      }

      if (_island.isOnLand(unitPosition)) {
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
            'Spawned ${unitType.name} for ${team.name} team at $unitPosition. Remaining: ${_getRemainingForType(team, unitType)}');

        // Force UI refresh after spawning
        forceRefreshUnitCounts();
        return;
      }
      attempts++;
    }

    debugPrint('Failed to find valid spawn location for ${unitType.name}');
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
        } else {
          // No selection, spawn units
          spawnUnitsAtPosition(_selectionStart!);
        }
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
    } else {
      // No selection, spawn units
      spawnUnitsAtPosition(info.eventPosition.global);
    }
    return true;
  }

  void spawnUnitsAtPosition(Vector2 position) {
    // Spawn only one unit of the current player's team
    Team team = _units.isEmpty || _units.last.model.team == Team.red
        ? Team.blue
        : Team.red;
    spawnUnits(1, position, team);
  }

  void spawnUnits(int count, Vector2 position, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    final rng = math.Random();
    int attempts = 0, spawned = 0;
    final int maxUnits = 2;
    bool hasCaptain = _units
        .any((u) => u.model.team == team && u.model.type == UnitType.captain);

    final coastline = _island.getCoastline();
    if (coastline.isEmpty) return;

    final apex = getIslandApex();
    if (apex == null) return;
    
    // Check if team has reached total unit limit
    int unitsRemaining = team == Team.blue ? blueUnitsRemaining : redUnitsRemaining;
    if (unitsRemaining <= 0) {
      debugPrint('${team.name} team has reached maximum total units');
      return;
    }

    while (spawned < maxUnits && spawned < unitsRemaining && attempts < maxUnits * 30) {
      final spawnPoint = coastline[rng.nextInt(coastline.length)];
      Vector2 unitPosition = Vector2(spawnPoint.dx, spawnPoint.dy);

      // Try to spawn slightly inland for better movement
      Vector2 toApex = Vector2(apex.dx, apex.dy) - unitPosition;
      toApex.normalize();
      // Move 15-25 pixels inland from coastline
      unitPosition += toApex.scaled(15 + rng.nextDouble() * 10);

      if (_island.isOnLand(unitPosition)) {
        UnitType unitType;
        if (!hasCaptain &&
            (team == Team.blue
                ? blueCaptainsRemaining > 0
                : redCaptainsRemaining > 0)) {
          unitType = UnitType.captain;
          hasCaptain = true;
        } else {
          // Allow flexible unit type selection based on what's available
          List<UnitType> availableTypes = [];
          
          if (team == Team.blue) {
            if (_blueArchersSpawned < maxArchersPerTeam) availableTypes.add(UnitType.archer);
            if (_blueSwordsmenSpawned < maxSwordsmenPerTeam) availableTypes.add(UnitType.swordsman);
          } else {
            if (_redArchersSpawned < maxArchersPerTeam) availableTypes.add(UnitType.archer);
            if (_redSwordsmenSpawned < maxSwordsmenPerTeam) availableTypes.add(UnitType.swordsman);
          }
          
          if (availableTypes.isEmpty) {
            break;
          }
          
          // Randomly select from available types
          unitType = availableTypes[rng.nextInt(availableTypes.length)];
        }

        final unitModel = UnitModel(
          id: 'unit_${DateTime.now().millisecondsSinceEpoch}_$spawned',
          type: unitType,
          position: unitPosition,
          team: team,
          velocity: toApex.scaled(8.0), // Slower velocity
          isOnLandCallback: isOnLand,
          getTerrainSpeedCallback:
              getMovementSpeedMultiplier, // Add terrain callback
        );

        // Immediately set target to apex
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

        spawned++;
      }
      attempts++;
    }

    debugPrint(
        'Spawned $spawned units for ${team.name} team. Blue remaining: $blueUnitsRemaining, Red remaining: $redUnitsRemaining');

    // Force UI refresh after spawning
    if (spawned > 0) {
      forceRefreshUnitCounts();
    }
  }
}
