// lib/game/island_game.dart
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'island_component.dart';
import 'unit_component.dart';
import 'ship_component.dart';
import '../models/ship_model.dart';
import '../models/unit_model.dart';
import '../models/player_model.dart';
import '../rules/game_rules.dart';
import '../services/pathfinding_service.dart';
import '../services/game_command_manager.dart';
import '../services/webrtc_game_service.dart';
import '../managers/unit_selection_manager.dart';
import '../constants/game_config.dart';
import 'dart:ui';

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
  double islandRadius;
  bool showPerimeter;

  // Player management
  final Map<String, Player> players = {
    'blue': Players.blue,
    'red': Players.red,
  };

  // Zoom and camera properties
  Vector2 cameraOrigin = Vector2.zero();
  double zoomLevel = 1.0;
  final double minZoom = 0.3;
  final double maxZoom = 3.0;
  late double startZoom;

  // Game components
  late IslandComponent _island;
  bool _isLoaded = false;
  final List<UnitComponent> _units = [];
  final List<ShipComponent> _ships = [];
  PathfindingService? _pathfindingService;

  // Game state
  bool _victoryAchieved = false;
  bool useAssets = false;
  GameState _currentGameState = GameState();
  double _lastRulesUpdate = 0.0;
  ShipComponent? _activeSpawnShip; // Currently selected ship for spawn controls
  
  // Long-tap detection
  DateTime? _tapStartTime;
  Vector2? _tapStartPosition;
  ShipComponent? _potentialLongTapShip;
  static const double _rulesUpdateInterval = kRulesUpdateInterval;

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

  // Game command manager for multiplayer synchronization
  GameCommandManager? _commandManager;
  String? _localPlayerId;

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
    required Vector2 gameSize, // Accept but don't store
    required this.islandRadius,
    this.showPerimeter = false,
  }) {
    _unitSelectionManager = UnitSelectionManager(this);
  }

  /// Initialize multiplayer command system
  void initializeMultiplayer(String localPlayerId) {
    _localPlayerId = localPlayerId;
    _commandManager = GameCommandManager(
      game: this,
      localPlayerId: localPlayerId,
    );
  }

  /// Initialize multiplayer with room code for RTDB
  Future<void> initializeMultiplayerWithRoom(String localPlayerId, String roomCode) async {
    _localPlayerId = localPlayerId;
    _commandManager = GameCommandManager(
      game: this,
      localPlayerId: localPlayerId,
    );
    
    // Initialize the command manager with room code
    await _commandManager!.initialize(roomCode);
    print('🎮 DEBUG: Multiplayer initialized with room: $roomCode');
  }

  /// Update multiplayer room code for Firebase fallback
  void updateMultiplayerRoom(String? roomCode) {
    // This method is now handled by initializeMultiplayerWithRoom
    print('🔄 DEBUG: updateMultiplayerRoom called with: $roomCode');
  }

  /// Check if multiplayer is enabled
  bool get isMultiplayerEnabled => _commandManager != null;

  /// Get command manager (for internal use by managers)
  GameCommandManager? get commandManager => _commandManager;

  void clampCamera() {
    final viewWidth = size.x / zoomLevel;
    final viewHeight = size.y / zoomLevel;
    final mapWidth = size.x;
    final mapHeight = size.y;

    cameraOrigin.x =
        cameraOrigin.x.clamp(0, (mapWidth - viewWidth).clamp(0, mapWidth));
    cameraOrigin.y =
        cameraOrigin.y.clamp(0, (mapHeight - viewHeight).clamp(0, mapHeight));
  }

  @override
  Color backgroundColor() => const Color(0xFF1a1a2e);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Create island with current size
    _island = IslandComponent(
      amplitude: amplitude,
      wavelength: wavelength,
      bias: bias,
      seed: seed,
      gameSize: size,
      islandRadius: islandRadius,
      showPerimeter: false,
    );
    _island.position = size / 2;
    add(_island);

    // Reset players
    Players.resetAll();
    GameRules.resetGame();

    // Wait for island to be fully loaded before spawning ships
    await Future.delayed(const Duration(milliseconds: 500));

    await _spawnInitialShips();

    _isLoaded = true;
    debugPrint('Island game loaded with size: ${size.x}x${size.y}');
  }

  Future<void> _spawnInitialShips() async {
    // Give island time to generate contours
    await Future.delayed(const Duration(milliseconds: 200));

    final coastline = getCoastline();
    if (coastline.isEmpty) {
      debugPrint("No coastline found, retrying...");
      // Try once more after another delay
      await Future.delayed(const Duration(milliseconds: 300));
      final retryCoastline = getCoastline();

      if (retryCoastline.isEmpty) {
        debugPrint("Still no coastline, using default ship spawn locations");
        _spawnShip(Team.blue, Vector2(size.x * 0.5, size.y * 0.1));
        _spawnShip(Team.red, Vector2(size.x * 0.5, size.y * 0.9));
        return;
      }
    }

    // Find extreme points on coastline
    final validCoastline = coastline.isNotEmpty ? coastline : getCoastline();
    if (validCoastline.isEmpty) {
      _spawnShip(Team.blue, Vector2(size.x * 0.5, size.y * 0.1));
      _spawnShip(Team.red, Vector2(size.x * 0.5, size.y * 0.9));
      return;
    }

    final northPoint = validCoastline.reduce((a, b) => a.dy < b.dy ? a : b);
    final southPoint = validCoastline.reduce((a, b) => a.dy > b.dy ? a : b);

    // Spawn ships further away from shore to avoid getting stuck
    final blueShipPos = Vector2(size.x * 0.5, northPoint.dy - 60);
    final redShipPos = Vector2(size.x * 0.5, southPoint.dy + 60);

    _spawnShip(Team.blue, blueShipPos);
    _spawnShip(Team.red, redShipPos);

    // Check if ships spawned in valid positions and fix if needed
    await Future.delayed(const Duration(milliseconds: 100));
    for (final ship in _ships) {
      if (ship.model.isStuck) {
        debugPrint("Ship ${ship.model.team} spawned stuck, unsticking...");
        ship.model.unstick();
      }
    }
  }

  bool _isNearShore(Vector2 position) {
    if (!_isLoaded || !_island.isMounted) return false;

    const double shoreDetectionRange = 40.0;
    const int checkPoints = 20;

    for (double radius = 15.0; radius <= shoreDetectionRange; radius += 5.0) {
      for (int i = 0; i < checkPoints; i++) {
        double angle = (i / checkPoints) * 2 * math.pi;
        Vector2 checkPos = position +
            Vector2(
              math.cos(angle) * radius,
              math.sin(angle) * radius,
            );

        if (isOnLand(checkPos)) {
          return true;
        }
      }
    }

    const double gridStep = 8.0;
    const double gridRange = 35.0;

    for (double x = -gridRange; x <= gridRange; x += gridStep) {
      for (double y = -gridRange; y <= gridRange; y += gridStep) {
        Vector2 checkPos = position + Vector2(x, y);

        if (isOnLand(checkPos)) {
          return true;
        }
      }
    }

    List<Vector2> directions = [
      Vector2(1, 0),
      Vector2(-1, 0),
      Vector2(0, 1),
      Vector2(0, -1),
      Vector2(1, 1),
      Vector2(-1, 1),
      Vector2(1, -1),
      Vector2(-1, -1),
    ];

    for (Vector2 direction in directions) {
      for (double distance = 10.0; distance <= 45.0; distance += 2.0) {
        Vector2 checkPos = position + direction * distance;

        if (isOnLand(checkPos)) {
          return true;
        }
      }
    }

    return false;
  }

  void _spawnShip(Team team, Vector2 position) {
    // Use deterministic ship IDs for multiplayer synchronization
    // Count existing ships of this team to ensure unique but predictable IDs
    final teamShipCount = _ships.where((ship) => ship.model.team == team).length;
    final shipModel = ShipModel(
      id: 'ship_${team.name}_${teamShipCount + 1}', // e.g., ship_blue_1, ship_red_1
      team: team,
      position: position,
      isOnLandCallback: isOnLand,
      isNearShoreCallback: _isNearShore,
    );

    final shipComponent = ShipComponent(model: shipModel);
    add(shipComponent);
    _ships.add(shipComponent);

    debugPrint(
        'Spawned ${team.name} turtle ship at $position with enhanced navigation');
  }

  @override
  void onGameResize(Vector2 newSize) {
    super.onGameResize(newSize);

    if (_isLoaded && _island.isMounted) {
      // Store old size for reference
      final oldSize = _island.gameSize.clone();

      // Calculate the center offset (how the center moves)
      final oldCenter = oldSize / 2;
      final newCenter = newSize / 2;
      final centerOffset = newCenter - oldCenter;

      // Update island size and position
      _island.gameSize = newSize;
      _island.position = newSize / 2;
      _island.size = newSize;

      // Update resolution in the island component
      _island.updateResolution(newSize.x, newSize.y);

      // Update camera region for the shader
      _island.updateCameraRegion(
        cameraX: 0,
        cameraY: 0,
        viewW: newSize.x,
        viewH: newSize.y,
      );

      // Update params to trigger full regeneration with new size
      _island.updateParams(
        amplitude: amplitude,
        wavelength: wavelength,
        bias: bias,
        seed: seed,
        islandRadius: islandRadius,
      );

      // Wait for contours to be recalculated before adjusting positions
      Future.delayed(const Duration(milliseconds: 100), () {
        // Only adjust positions by the center offset to keep objects in the same world position
        // This maintains their position relative to the island features
        for (final ship in _ships) {
          ship.model.position += centerOffset;
          ship.position = ship.model.position.clone();
        }

        // Adjust unit positions by center offset
        for (final unit in _units) {
          unit.model.position += centerOffset;
          unit.position = unit.model.position.clone();

          // Also adjust target position if it exists
          if (unit.model.targetPosition != null) {
            unit.model.targetPosition += centerOffset;
          }
        }

        // Adjust camera by center offset to maintain view
        cameraOrigin += centerOffset;

        // Clamp camera to ensure it's within bounds
        clampCamera();
      });
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
    this.showPerimeter = false;

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

  Vector2 screenToWorldPosition(Vector2 screenPos) {
    return cameraOrigin + screenPos / zoomLevel;
  }

  Vector2 worldToScreenPosition(Vector2 worldPos) {
    return (worldPos - cameraOrigin) * zoomLevel;
  }

  /// Convert world coordinates to island-relative coordinates
  /// This ensures consistent coordinates across different devices
  Vector2 worldToIslandRelative(Vector2 worldPos) {
    final islandCenter = _island.position;
    return worldPos - islandCenter;
  }

  /// Convert island-relative coordinates to world coordinates
  Vector2 islandRelativeToWorld(Vector2 relativePos) {
    final islandCenter = _island.position;
    return relativePos + islandCenter;
  }

  @override
  bool onTapDown(TapDownInfo info) {
    final screenPos = info.eventPosition.global;
    final worldBeforeZoom = screenToWorldPosition(screenPos);

    // Start long-tap detection
    _tapStartTime = DateTime.now();
    _tapStartPosition = worldBeforeZoom.clone();
    
    // Check if tapping on a ship for potential long-tap
    final tappedShip = _findShipAtPosition(worldBeforeZoom);
    _potentialLongTapShip = tappedShip;

    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 300) {
      final newZoom = zoomLevel > 1.0 ? 1.0 : 1.75;
      zoomLevel = newZoom;
      cameraOrigin =
          worldBeforeZoom - Vector2(size.x / 2, size.y / 2) / zoomLevel;
      clampCamera();
      _lastTapTime = DateTime.now().subtract(const Duration(milliseconds: 500));
      return true;
    }
    _lastTapTime = now;

    return true; // Continue processing in onTapUp
  }

  @override
  bool onTapUp(TapUpInfo info) {
    final screenPos = info.eventPosition.global;
    final worldPos = screenToWorldPosition(screenPos);
    
    // Check for long-tap
    if (_tapStartTime != null && _tapStartPosition != null) {
      final tapDuration = DateTime.now().difference(_tapStartTime!);
      final tapDistance = worldPos.distanceTo(_tapStartPosition!);
      
      // Long-tap detected (>500ms and <50 pixels movement)
      if (tapDuration.inMilliseconds > 500 && tapDistance < 50) {
        if (_potentialLongTapShip != null) {
          _potentialLongTapShip!.onLongTap();
          _resetTapDetection();
          return true;
        }
      }
    }
    
    // Regular tap handling
    final tappedShip = _findShipAtPosition(worldPos);
    if (tappedShip != null) {
      _unitSelectionManager.handleShipTap(tappedShip);
      _notifyUIUpdate();
      _resetTapDetection();
      return true;
    }

    final tappedUnit = _findUnitAtPosition(worldPos);
    if (tappedUnit != null) {
      _unitSelectionManager.handleUnitTap(tappedUnit);
      _notifyUIUpdate();
      _resetTapDetection();
      return true;
    }

    _unitSelectionManager.handleEmptyTap(worldPos);
    _notifyUIUpdate();
    _resetTapDetection();

    return true;
  }
  
  /// Reset tap detection variables
  void _resetTapDetection() {
    _tapStartTime = null;
    _tapStartPosition = null;
    _potentialLongTapShip = null;
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
        _unitSelectionManager.selectUnitsInBox(
            _selectionStart!, _selectionEnd!);
        _notifyUIUpdate();
      } else {
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

  @override
  void onScroll(PointerScrollInfo info) {
    const zoomPerScrollUnit = 0.05;
    zoomLevel += info.scrollDelta.global.y.sign * -zoomPerScrollUnit;
    zoomLevel = zoomLevel.clamp(minZoom, maxZoom);
    clampCamera();
  }

  ShipComponent? _findShipAtPosition(Vector2 worldPosition) {
    final shipsWithDistance = <MapEntry<ShipComponent, double>>[];

    for (final ship in _ships) {
      if (ship.model.isDestroyed) continue;

      final distance = ship.position.distanceTo(worldPosition);
      if (distance <= ship.model.radius + 15) {
        shipsWithDistance.add(MapEntry(ship, distance));
      }
    }

    if (shipsWithDistance.isNotEmpty) {
      shipsWithDistance.sort((a, b) => a.value.compareTo(b.value));
      return shipsWithDistance.first.key;
    }

    return null;
  }

  bool deployUnitFromShip(UnitType unitType, Team team) {
    final teamShips =
        _ships.where((s) => s.model.team == team && s.model.canDeployUnits());

    for (final ship in teamShips) {
      if (ship.model.canDeployUnits()) {
        final deployedType = ship.deployUnit(unitType);
        if (deployedType != null) {
          final deployPos = ship.getDeploymentPosition();
          if (deployPos != null) {
            spawnUnitAtPosition(deployedType, team, deployPos);
            return true;
          }
        }
      }
    }
    return false;
  }

  void spawnUnitAtPosition(UnitType unitType, Team team, Vector2 position) {
    final playerId = team == Team.blue ? 'blue' : 'red';
    final player = players[playerId]!;

    // Generate deterministic unit ID for multiplayer synchronization
    String unitId;
    if (isMultiplayerEnabled) {
      // In multiplayer, use deterministic IDs based on team and unit count
      final teamUnitCount = _units.where((u) => u.model.team == team).length;
      unitId = 'unit_${playerId}_${unitType.name}_${teamUnitCount + 1}';
      print('🆕 DEBUG: Spawning unit in MULTIPLAYER mode');
      print('🆕 DEBUG: Team: $playerId, Type: ${unitType.name}, Count: ${teamUnitCount + 1}');
      print('🆕 DEBUG: Generated ID: $unitId');
    } else {
      // In single player, use timestamp-based IDs
      unitId = 'unit_${DateTime.now().millisecondsSinceEpoch}_${playerId}_${unitType.name}';
      print('🆕 DEBUG: Spawning unit in SINGLE-PLAYER mode');
      print('🆕 DEBUG: Generated ID: $unitId');
    }

    print('🆕 DEBUG: Spawning unit at position: (${position.x}, ${position.y})');

    final unitModel = UnitModel(
      id: unitId,
      type: unitType,
      position: position,
      playerId: playerId,
      isOnLandCallback: isOnLand,
      getTerrainSpeedCallback: getMovementSpeedMultiplier,
    );

    final unitComponent = UnitComponent(model: unitModel);
    add(unitComponent);
    _units.add(unitComponent);

    // Update player spawn counts
    player.spawnedUnits[unitType] = player.spawnedUnits[unitType]! + 1;
    player.unitsRemaining--;

    debugPrint(
        'Deployed ${unitType.name} for ${player.name} at $position from ship');
    _notifyUIUpdate();
  }

  UnitComponent? _findUnitAtPosition(Vector2 worldPosition) {
    final unitsWithDistance = <MapEntry<UnitComponent, double>>[];

    for (final unit in _units) {
      if (unit.model.health <= 0) continue;

      final distance = unit.position.distanceTo(worldPosition);
      if (distance <= unit.model.radius + 10) {
        unitsWithDistance.add(MapEntry(unit, distance));
      }
    }

    if (unitsWithDistance.isNotEmpty) {
      unitsWithDistance.sort((a, b) => a.value.compareTo(b.value));
      return unitsWithDistance.first.key;
    }

    return null;
  }

  void clearSelection() {
    _unitSelectionManager.clearSelection();
    _notifyUIUpdate();
  }

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

  void createDestinationMarker(Vector2 worldPosition) {
    _createDestinationMarker(worldPosition);
  }

  void _updateDestinationMarker(double dt) {
    if (_destinationMarker != null) {
      _markerTimer += dt;
      _markerPulseScale = 1.0 + 0.5 * math.sin(_markerTimer * 4);
      _markerOpacity -= dt * 0.05;

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

  void zoomIn() {
    zoomLevel = (zoomLevel + 0.25).clamp(minZoom, maxZoom);
    clampCamera();
  }

  void zoomOut() {
    zoomLevel = (zoomLevel - 0.25).clamp(minZoom, maxZoom);
    clampCamera();
  }

  void resetZoom() {
    zoomLevel = 1.0;
    cameraOrigin = Vector2.zero();
    clampCamera();
  }

  void zoomAt(double newZoom, Vector2 focalPoint) {
    final worldBeforeZoom = screenToWorldPosition(focalPoint);
    zoomLevel = newZoom.clamp(minZoom, maxZoom);
    cameraOrigin = worldBeforeZoom - focalPoint / zoomLevel;
    clampCamera();
  }

  void panCamera(Vector2 direction) {
    const panSpeed = 50.0;
    final scaledDirection = direction.normalized() * panSpeed / zoomLevel;
    cameraOrigin += scaledDirection;
    clampCamera();
  }

  void panUp() => panCamera(Vector2(0, -1));
  void panDown() => panCamera(Vector2(0, 1));
  void panLeft() => panCamera(Vector2(-1, 0));
  void panRight() => panCamera(Vector2(1, 0));

  void spawnSingleUnit(UnitType unitType, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    final playerId = team == Team.blue ? 'blue' : 'red';
    final player = players[playerId]!;

    if (!player.canSpawnUnit(unitType)) {
      debugPrint('${player.name} cannot spawn more ${unitType.name} units');
      return;
    }

    if (deployUnitFromShip(unitType, team)) {
      return;
    }

    final apex = getIslandApex();
    if (apex == null) return;

    final coastline = getCoastline();
    if (coastline.isEmpty) {
      debugPrint("No coastline found, using default spawn locations");
      return;
    }

    final northPoint = coastline.reduce((a, b) => a.dy < b.dy ? a : b);
    final southPoint = coastline.reduce((a, b) => a.dy > b.dy ? a : b);

    final baseSpawnY =
        team == Team.blue ? northPoint.dy + 50 : southPoint.dy - 50;
    final rng = math.Random();
    final spawnX = size.x / 2 + (rng.nextDouble() * 60 - 30);
    final unitPosition = Vector2(spawnX, baseSpawnY);

    spawnUnitAtPosition(unitType, team, unitPosition);
  }

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

      // Update player units remaining from game rules
      players['blue']!.unitsRemaining = _currentGameState.blueUnitsRemaining;
      players['red']!.unitsRemaining = _currentGameState.redUnitsRemaining;

      bool unitsRemoved = false;
      for (final unitId in _currentGameState.unitsToRemove) {
        final unitToRemove =
            _units.where((u) => u.model.id == unitId).firstOrNull;
        if (unitToRemove != null) {
          _decrementUnitCount(
              unitToRemove.model.playerId, unitToRemove.model.type);

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

  void _renderSelectedShipPaths(Canvas canvas) {
    for (final ship in _ships) {
      if (!ship.model.isSelected || !ship.model.isNavigating) continue;
      if (ship.model.navigationPath == null ||
          ship.model.navigationPath!.isEmpty) continue;

      final pathPaint = Paint()
        ..color = ship.model.team == Team.blue
            ? Colors.blue.withOpacity(0.6)
            : Colors.red.withOpacity(0.6)
        ..strokeWidth = 3 / zoomLevel
        ..style = PaintingStyle.stroke;

      final waypointPaint = Paint()
        ..color = ship.model.team == Team.blue
            ? Colors.blue.withOpacity(0.8)
            : Colors.red.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      Vector2 currentPos = ship.position;
      for (int i = 0; i < ship.model.navigationPath!.length; i++) {
        Vector2 waypoint = ship.model.navigationPath![i];

        Vector2 currentScreen = worldToScreenPosition(currentPos);
        Vector2 waypointScreen = worldToScreenPosition(waypoint);

        canvas.drawLine(
          Offset(currentScreen.x, currentScreen.y),
          Offset(waypointScreen.x, waypointScreen.y),
          pathPaint,
        );

        canvas.drawCircle(
          Offset(waypointScreen.x, waypointScreen.y),
          4 / zoomLevel,
          waypointPaint,
        );

        currentPos = waypoint;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-cameraOrigin.x * zoomLevel, -cameraOrigin.y * zoomLevel);
    canvas.scale(zoomLevel);
    super.render(canvas);
    canvas.restore();

    if (_isDragging && _selectionStart != null && _selectionEnd != null) {
      final rect = Rect.fromPoints(
        Offset(_selectionStart!.x, _selectionStart!.y),
        Offset(_selectionEnd!.x, _selectionEnd!.y),
      );
      canvas.drawRect(rect, _selectionPaint);
      canvas.drawRect(rect, _selectionBorderPaint);
    }

    if (_destinationMarker != null) {
      final screenPos = worldToScreenPosition(_destinationMarker!);
      _drawDestinationMarker(canvas, screenPos);
    }

    _unitSelectionManager.renderAttackRange(canvas);
    _renderSelectedShipPaths(canvas);
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

  void _decrementUnitCount(String playerId, UnitType type) {
    final player = players[playerId]!;

    if (player.spawnedUnits[type]! > 0) {
      player.spawnedUnits[type] = player.spawnedUnits[type]! - 1;
    }

    _notifyUIUpdate();
  }

  void _notifyUIUpdate() {
    try {
      if (onUnitCountsChanged != null) {
        onUnitCountsChanged!();
      }
    } catch (e) {
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

  // Player-based getters
  int getPlayerUnitCount(String playerId) {
    return _units
        .where((u) => u.model.playerId == playerId && u.model.health > 0)
        .length;
  }

  // Backward compatibility getters
  int get blueUnitCount => getPlayerUnitCount('blue');
  int get redUnitCount => getPlayerUnitCount('red');
  int get blueUnitsRemaining => players['blue']!.unitsRemaining;
  int get redUnitsRemaining => players['red']!.unitsRemaining;
  int get blueCaptainsRemaining =>
      players['blue']!.getRemainingUnits(UnitType.captain);
  int get blueArchersRemaining =>
      players['blue']!.getRemainingUnits(UnitType.archer);
  int get blueSwordsmenRemaining =>
      players['blue']!.getRemainingUnits(UnitType.swordsman);
  int get redCaptainsRemaining =>
      players['red']!.getRemainingUnits(UnitType.captain);
  int get redArchersRemaining =>
      players['red']!.getRemainingUnits(UnitType.archer);
  int get redSwordsmenRemaining =>
      players['red']!.getRemainingUnits(UnitType.swordsman);

  int get blueUnitsSpawned {
    final player = players['blue']!;
    return player.spawnedUnits.values.fold(0, (sum, count) => sum + count);
  }

  int get redUnitsSpawned {
    final player = players['red']!;
    return player.spawnedUnits.values.fold(0, (sum, count) => sum + count);
  }

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
  List<ShipComponent> getAllShips() => _ships;

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
        .where((u) => u.model.playerId == 'blue' && u.model.health > 0)
        .length;
    final redCount = _units
        .where((u) => u.model.playerId == 'red' && u.model.health > 0)
        .length;

    if ((blueCount > 0 &&
            redCount == 0 &&
            players['red']!.unitsRemaining == 0) ||
        (redCount > 0 &&
            blueCount == 0 &&
            players['blue']!.unitsRemaining == 0)) {
      _victoryAchieved = true;
      return true;
    }

    return false;
  }

  int get blueShipCount => _ships
      .where((s) => s.model.team == Team.blue && !s.model.isDestroyed)
      .length;
  int get redShipCount => _ships
      .where((s) => s.model.team == Team.red && !s.model.isDestroyed)
      .length;

  double get blueHealthPercent {
    final blueUnits = _units
        .where((u) => u.model.playerId == 'blue' && u.model.health > 0)
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
        .where((u) => u.model.playerId == 'red' && u.model.health > 0)
        .toList();
    if (redUnits.isEmpty) return 0.0;
    final totalHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.health);
    final maxHealth =
        redUnits.fold(0.0, (sum, unit) => sum + unit.model.maxHealth);
    return maxHealth > 0 ? totalHealth / maxHealth : 0.0;
  }

  List<UnitComponent> get selectedUnits => _unitSelectionManager.selectedUnits;
  List<ShipComponent> get selectedShips => _unitSelectionManager.selectedShips;
  UnitSelectionManager get unitSelectionManager => _unitSelectionManager;
  UnitComponent? get selectedUnit =>
      _unitSelectionManager.selectedUnits.isNotEmpty
          ? _unitSelectionManager.selectedUnits.first
          : null;
  ShipComponent? get selectedShip =>
      _unitSelectionManager.selectedShips.isNotEmpty
          ? _unitSelectionManager.selectedShips.first
          : null;

  List<Map<String, dynamic>> getSelectedUnitsInfo() {
    final List<Map<String, dynamic>> objectsInfo = [];

    final selectedUnits = _unitSelectionManager.selectedUnits;
    for (final unit in selectedUnits) {
      final healthPercent =
          (unit.model.health / unit.model.maxHealth * 100).toInt();
      final typeStr = unit.model.type.toString().split('.').last;
      final teamStr = unit.model.team.toString().split('.').last;

      objectsInfo.add({
        'type': typeStr.toUpperCase(),
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'hasFlag':
            unit.model.type == UnitType.captain && unit.model.hasPlantedFlag,
        'id': unit.model.id,
        'objectType': 'UNIT',
        'isTargeted': unit.model.isTargeted,
      });
    }

    final selectedShips = _unitSelectionManager.selectedShips;
    for (final ship in selectedShips) {
      final healthPercent = (ship.model.healthPercent * 100).toInt();
      final teamStr = ship.model.team.toString().split('.').last;
      final cargo = ship.model.getAvailableUnits();

      objectsInfo.add({
        'type': 'TURTLE SHIP',
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'status': ship.model.getStatusText(),
        'cargo': cargo,
        'canDeploy': ship.model.canDeployUnits(),
        'id': ship.model.id,
        'objectType': 'SHIP',
      });
    }

    return objectsInfo;
  }

  List<Map<String, dynamic>> getSelectedObjectsInfo() {
    return _unitSelectionManager.getSelectedObjectsInfo();
  }

  /// Show contextual spawn controls for a specific ship
  void showShipSpawnControls(ShipComponent ship) {
    // Hide any existing spawn controls first
    hideShipSpawnControls();
    
    // Only show controls for ships that can deploy units
    if (!ship.model.canDeployUnits()) {
      print('🚢 DEBUG: Ship cannot deploy units - ${ship.model.getStatusText()}');
      return;
    }
    
    // Check if this ship belongs to the local player in multiplayer
    if (isMultiplayerEnabled) {
      final commandManager = _commandManager;
      if (commandManager != null) {
        final shipTeam = ship.model.team == Team.blue ? 'blue' : 'red';
        final localTeam = commandManager.localPlayerId == 'blue' || commandManager.localPlayerId == 'red' 
            ? commandManager.localPlayerId 
            : (WebRTCGameService.instance.isHost ? 'blue' : 'red');
            
        if (shipTeam != localTeam) {
          print('🚢 DEBUG: Cannot control opponent ship (${ship.model.team.name})');
          return;
        }
      }
    }
    
    // Store reference to the ship for spawn controls
    _activeSpawnShip = ship;
    
    // Notify UI to show spawn controls
    _notifyUIUpdate();
    
    print('🚢 DEBUG: Showing spawn controls for ${ship.model.team.name} ship');
    print('🚢 DEBUG: Available units: ${ship.model.getAvailableUnits()}');
  }
  
  /// Hide ship spawn controls
  void hideShipSpawnControls() {
    if (_activeSpawnShip != null) {
      _activeSpawnShip = null;
      _notifyUIUpdate();
      print('🚢 DEBUG: Hiding spawn controls');
    }
  }
  
  /// Get the currently active spawn ship
  ShipComponent? get activeSpawnShip => _activeSpawnShip;
  @override
  void onRemove() {
    _commandManager?.dispose();
    super.onRemove();
  }

  /// Get selected ship cargo information
  Map<String, dynamic>? getSelectedShipCargo() {
    final selectedShips = _unitSelectionManager.selectedShips;
    if (selectedShips.isEmpty) return null;

    final ship = selectedShips.first;
    final cargo = ship.model.getAvailableUnits();

    return {
      'canDeploy': ship.model.canDeployUnits(),
      'status': ship.model.getStatusText(),
      'captains': cargo[UnitType.captain] ?? 0,
      'archers': cargo[UnitType.archer] ?? 0,
      'swordsmen': cargo[UnitType.swordsman] ?? 0,
      'total': ship.model.cargoCount,
    };
  }

  bool deployUnitFromSelectedShip(UnitType unitType) {
    final selectedShips = _unitSelectionManager.selectedShips;
    if (selectedShips.isEmpty) return false;

    return _unitSelectionManager.deployUnitFromShip(unitType);
  }

  void toggleApexMarker(bool show) {}

  void spawnUnitsAtPosition(Vector2 position) {}

  void spawnUnits(int count, Vector2 position, Team team) {
    if (!_isLoaded || !_island.isMounted) return;

    final playerId = team == Team.blue ? 'blue' : 'red';
    final player = players[playerId]!;

    if (player.unitsRemaining <= 0) {
      debugPrint('${player.name} has reached maximum total units');
      return;
    }

    // Spawn the requested number of units
    for (int i = 0; i < count && player.unitsRemaining > 0; i++) {
      final unitModels = _units.map((u) => u.model).toList();
      final hasCaptain = unitModels.any((u) =>
          u.playerId == playerId && u.type == UnitType.captain && u.health > 0);

      if (!hasCaptain) {
        _spawnSingleUnit(UnitType.captain, team);
      } else {
        final rng = math.Random();
        _spawnSingleUnit(
            rng.nextBool() ? UnitType.archer : UnitType.swordsman, team);
      }
    }

    debugPrint(
        "Spawned units for ${player.name}. Units remaining: ${player.unitsRemaining}");
  }

  /// Spawn a single unit (internal helper method)
  void _spawnSingleUnit(UnitType unitType, Team team) {
    // This is a simplified version - you may need to adjust based on your game logic
    final playerId = team == Team.blue ? 'blue' : 'red';
    final spawnPosition = Vector2(size.x / 2, size.y / 2); // Default center position
    spawnUnitAtPosition(unitType, team, spawnPosition);
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
