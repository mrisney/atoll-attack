import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'island_component.dart';
import 'unit_component.dart';
import '../models/unit_model.dart';
import '../rules/victory_conditions.dart';
import '../rules/combat_rules.dart';
import '../rules/game_rules_engine.dart';
import '../services/pathfinding_service.dart';
import '../config.dart';
import 'dart:math';

class IslandGame extends FlameGame with HasCollisionDetection, TapDetector {
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
  UnitComponent? _selectedUnit;
  bool _victoryAchieved = false;
  bool useAssets = false; // Toggle for using artwork vs simple shapes

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
    // Keep perimeter flag in sync
    if (_isLoaded && _island.isMounted) {
      _island.showPerimeter = showPerimeter;
    }

    // Process game rules periodically
    processGameRules();
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

  // Pathfinding service
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
    if (!_victoryAchieved) {
      _victoryAchieved = true;
      debugPrint('Victory! Captain has planted the flag at the apex!');
      // Here you could trigger victory animations, sounds, etc.
    }
  }

  bool isVictoryAchieved() {
    return _victoryAchieved;
  }

  void selectUnit(Vector2 position) {
    // Deselect current unit if any
    if (_selectedUnit != null) {
      _selectedUnit!.setSelected(false);
      _selectedUnit = null;
    }

    // Find unit under touch position
    for (final unit in _units) {
      if (unit.containsPoint(position)) {
        unit.setSelected(true);
        _selectedUnit = unit;
        break;
      }
    }
  }

  void moveSelectedUnit(Vector2 target) {
    if (_selectedUnit != null && isOnLand(target)) {
      _selectedUnit!.setTargetPosition(target);
    }
  }

  void checkVictoryConditions() {
    // Get all unit models
    final unitModels = _units.map((u) => u.model).toList();

    // Use victory conditions class to check for winners
    final winningTeam = VictoryConditions.getWinningTeam(unitModels);

    if (winningTeam != null) {
      _victoryAchieved = true;
      debugPrint('${winningTeam == Team.blue ? "Blue" : "Red"} team wins!');
    }
  }

  // Rules engine processing
  void processGameRules() {
    _lastRulesUpdate += 1 / 60; // Approximate frame time

    if (_lastRulesUpdate >= _rulesUpdateInterval) {
      _lastRulesUpdate = 0.0;

      final unitModels = _units.map((u) => u.model).toList();
      _currentGameState = GameRulesEngine.processRules(
        unitModels,
        apex: getIslandApex(),
      );

      // Handle unit removal - also update spawn counters
      for (final unitId in _currentGameState.unitsToRemove) {
        final unitToRemove =
            _units.where((u) => u.model.id == unitId).firstOrNull;
        if (unitToRemove != null) {
          // Decrease spawn counter when unit dies based on type
          _decrementUnitCount(unitToRemove.model.team, unitToRemove.model.type);

          // Notify providers of unit count change
          onUnitCountsChanged?.call();

          // Add death animation before removal
          unitToRemove.playDeathAnimation();

          // Remove after a short delay to allow animation
          Future.delayed(const Duration(milliseconds: 800), () {
            if (unitToRemove.isMounted) {
              unitToRemove.removeFromParent();
              _units.remove(unitToRemove);
            }
          });
        }
      }

      // Check victory conditions
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
      }
    }
  }

  // Helper method to decrement unit counts
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
  }

  // Getter methods for the HUD
  int get blueUnitCount => _currentGameState.blueUnits;
  int get redUnitCount => _currentGameState.redUnits;
  double get blueHealthPercent => _currentGameState.blueHealthPercent;
  double get redHealthPercent => _currentGameState.redHealthPercent;

  // Updated unit remaining calculations
  int get blueUnitsRemaining =>
      (maxCaptainsPerTeam - _blueCaptainsSpawned) +
      (maxArchersPerTeam - _blueArchersSpawned) +
      (maxSwordsmenPerTeam - _blueSwordsmenSpawned);
  int get redUnitsRemaining =>
      (maxCaptainsPerTeam - _redCaptainsSpawned) +
      (maxArchersPerTeam - _redArchersSpawned) +
      (maxSwordsmenPerTeam - _redSwordsmenSpawned);

  // Individual unit type getters for controls panel
  int get blueCaptainsRemaining => maxCaptainsPerTeam - _blueCaptainsSpawned;
  int get blueArchersRemaining => maxArchersPerTeam - _blueArchersSpawned;
  int get blueSwordsmenRemaining => maxSwordsmenPerTeam - _blueSwordsmenSpawned;
  int get redCaptainsRemaining => maxCaptainsPerTeam - _redCaptainsSpawned;
  int get redArchersRemaining => maxArchersPerTeam - _redArchersSpawned;
  int get redSwordsmenRemaining => maxSwordsmenPerTeam - _redSwordsmenSpawned;

  // Spawned unit count getters for game provider
  int get blueUnitsSpawned =>
      _blueCaptainsSpawned + _blueArchersSpawned + _blueSwordsmenSpawned;
  int get redUnitsSpawned =>
      _redCaptainsSpawned + _redArchersSpawned + _redSwordsmenSpawned;

  // Selected unit getter
  UnitComponent? get selectedUnit => _selectedUnit;

  // New method to spawn single unit of specific type
  void spawnSingleUnit(UnitType unitType, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    // Check unit limits for specific type
    bool canSpawn = false;
    if (team == Team.blue) {
      switch (unitType) {
        case UnitType.captain:
          canSpawn = _blueCaptainsSpawned < maxCaptainsPerTeam;
        case UnitType.archer:
          canSpawn = _blueArchersSpawned < maxArchersPerTeam;
        case UnitType.swordsman:
          canSpawn = _blueSwordsmenSpawned < maxSwordsmenPerTeam;
      }
    } else {
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

    final rng = Random();
    int attempts = 0;

    // Get coastline for spawning units on the perimeter
    final coastline = _island.getCoastline();
    if (coastline.isEmpty) return;

    // Get apex for movement target
    final apex = getIslandApex();
    if (apex == null) return;

    while (attempts < 50) {
      // Try up to 50 times to find a valid spawn point
      // Spawn on a random point along the coastline
      final spawnPoint = coastline[rng.nextInt(coastline.length)];
      final unitPosition = Vector2(spawnPoint.dx, spawnPoint.dy);

      if (_island.isOnLand(unitPosition)) {
        // Create unit model with slower initial velocity
        Vector2 toApex = Vector2(apex.dx, apex.dy) - unitPosition;
        toApex.normalize();

        final unitModel = UnitModel(
          id: 'unit_${DateTime.now().millisecondsSinceEpoch}_${team.name}_${unitType.name}',
          type: unitType,
          position: unitPosition,
          team: team,
          velocity: toApex.scaled(5.0),
          isOnLandCallback: isOnLand,
        );

        // Create unit component
        final unitComponent = UnitComponent(model: unitModel);
        add(unitComponent);
        _units.add(unitComponent);

        // Update spawn counter for specific type
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

        // Notify providers of unit count change
        onUnitCountsChanged?.call();

        debugPrint(
            'Spawned ${unitType.name} for ${team.name} team. Remaining: ${_getRemainingForType(team, unitType)}');
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

  void spawnUnits(int count, Vector2 position, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    final rng = Random();
    int attempts = 0, spawned = 0;

    // Spawn exactly 2 units: one captain and one other unit
    final int maxUnits = 2;
    bool hasCaptain = _units
        .any((u) => u.model.team == team && u.model.type == UnitType.captain);

    // Get coastline for spawning units on the perimeter
    final coastline = _island.getCoastline();
    if (coastline.isEmpty) return;

    // Get apex for movement target
    final apex = getIslandApex();
    if (apex == null) return;

    while (spawned < maxUnits && attempts < maxUnits * 20) {
      // Spawn on a random point along the coastline
      final spawnPoint = coastline[rng.nextInt(coastline.length)];
      final unitPosition = Vector2(spawnPoint.dx, spawnPoint.dy);

      if (_island.isOnLand(unitPosition)) {
        // Determine unit type - prioritize captain if none exists
        UnitType unitType;
        if (!hasCaptain &&
            (team == Team.blue
                ? blueCaptainsRemaining > 0
                : redCaptainsRemaining > 0)) {
          unitType = UnitType.captain;
          hasCaptain = true;
        } else {
          // Random between swordsman and archer, check availability
          bool canSpawnArcher = team == Team.blue
              ? blueArchersRemaining > 0
              : redArchersRemaining > 0;
          bool canSpawnSwordsman = team == Team.blue
              ? blueSwordsmenRemaining > 0
              : redSwordsmenRemaining > 0;

          if (canSpawnArcher && canSpawnSwordsman) {
            unitType = rng.nextBool() ? UnitType.swordsman : UnitType.archer;
          } else if (canSpawnArcher) {
            unitType = UnitType.archer;
          } else if (canSpawnSwordsman) {
            unitType = UnitType.swordsman;
          } else {
            break; // No units available to spawn
          }
        }

        // Create unit model with slower initial velocity
        Vector2 toApex = Vector2(apex.dx, apex.dy) - unitPosition;
        toApex.normalize();

        final unitModel = UnitModel(
          id: 'unit_${DateTime.now().millisecondsSinceEpoch}_$spawned',
          type: unitType,
          position: unitPosition,
          team: team,
          velocity: toApex.scaled(5.0), // Much slower initial velocity
          isOnLandCallback: isOnLand, // Pass the land check callback
        );

        // Create unit component
        final unitComponent = UnitComponent(model: unitModel);
        add(unitComponent);
        _units.add(unitComponent);

        // Update spawn counters for specific type
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

    // Notify providers of unit count change if any units were spawned
    if (spawned > 0) {
      onUnitCountsChanged?.call();
    }

    debugPrint(
        'Spawned $spawned units for ${team.name} team. Blue remaining: $blueUnitsRemaining, Red remaining: $redUnitsRemaining');
  }

  // Legacy method for compatibility with existing code
  void spawnUnitsLegacy(int count) {
    // Use center of screen as default position
    spawnUnitsAtPosition(gameSize / 2);
  }

  void spawnUnitsAtPosition(Vector2 position) {
    // Alternate between teams for testing
    Team team = _units.isEmpty || _units.last.model.team == Team.red
        ? Team.blue
        : Team.red;
    spawnUnits(2, position, team);
  }

  @override
  void onTap() {
    if (_victoryAchieved) return;

    final touchPosition = camera.viewfinder.position;

    // Check if we tapped on a unit
    bool tappedOnUnit = false;
    for (final unit in _units) {
      if (unit.containsPoint(touchPosition)) {
        selectUnit(touchPosition);
        tappedOnUnit = true;
        break;
      }
    }

    // If not tapped on a unit, spawn new units
    if (!tappedOnUnit) {
      spawnUnitsAtPosition(touchPosition);
    }
  }
}
