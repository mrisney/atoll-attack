// Updated unit_selection_manager.dart with improved ship selection and controls

import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';
import '../game/unit_component.dart';
import '../game/ship_component.dart';
import '../game/arrow_component.dart';
import '../game/island_game.dart';

/// Manages unit and ship selection, targeting, and movement logic
class UnitSelectionManager {
  // Selected units and ships
  final List<UnitComponent> _selectedUnits = [];
  final List<ShipComponent> _selectedShips = [];

  // Targeted units (units that selected units will attack)
  final List<UnitComponent> _targetedUnits = [];

  // Reference to game
  final IslandGame game;

  // Selection state tracking
  UnitComponent? _lastSelectedUnit;
  ShipComponent? _lastSelectedShip;
  UnitComponent? _targetUnit;
  bool _isSelectingTarget = false;

  // Attack range visualization
  double? _attackRangeRadius;
  Vector2? _attackRangeCenter;

  // Team that player is controlling
  Team? _playerTeam;

  // DEVELOPMENT MODE FLAG - Set to true to allow selecting both teams
  static const bool developmentMode = true;

  UnitSelectionManager(this.game);

  // Getters
  List<UnitComponent> get selectedUnits => List.unmodifiable(_selectedUnits);
  List<ShipComponent> get selectedShips => List.unmodifiable(_selectedShips);
  List<UnitComponent> get targetedUnits => List.unmodifiable(_targetedUnits);
  bool get hasSelection =>
      _selectedUnits.isNotEmpty || _selectedShips.isNotEmpty;
  bool get hasTargets => _targetedUnits.isNotEmpty;
  bool get isSelectingTarget => _isSelectingTarget;
  UnitComponent? get lastSelectedUnit => _lastSelectedUnit;
  ShipComponent? get lastSelectedShip => _lastSelectedShip;
  Team? get playerTeam => _playerTeam;

  /// Set the player's team
  void setPlayerTeam(Team team) {
    _playerTeam = team;
  }

  /// Handle tap on a ship - primary selection method for ships
  bool handleShipTap(ShipComponent tappedShip) {
    // If tapping the same ship that's already selected, deselect it
    if (_selectedShips.contains(tappedShip)) {
      clearSelection();
      return true;
    }

    // Clear previous selection
    clearSelection();

    // Select the tapped ship
    tappedShip.model.isSelected = true;
    _selectedShips.add(tappedShip);
    _lastSelectedShip = tappedShip;

    // Show ship info
    tappedShip.showShipInfo();

    return true;
  }

  /// Handle tap on a unit
  bool handleUnitTap(UnitComponent tappedUnit) {
    // If we're in targeting mode and tap on a valid target
    if (_isSelectingTarget) {
      // Check if tapped unit is a valid target (enemy unit)
      if (_lastSelectedUnit != null &&
          tappedUnit.model.team != _lastSelectedUnit!.model.team) {
        _targetUnit = tappedUnit;
        _attackTarget();
        return true;
      } else {
        // Cancel targeting mode if tapping on friendly unit
        _isSelectingTarget = false;
        _attackRangeRadius = null;
        _attackRangeCenter = null;
      }
    }

    // Check if tapped unit is already targeted - if so, remove targeting
    if (_targetedUnits.contains(tappedUnit)) {
      _removeTarget(tappedUnit);
      return true;
    }

    // DEVELOPMENT MODE: Allow attacking any unit regardless of team
    if (developmentMode) {
      // If we have selected units and tap on a different team unit, set as target
      if (_selectedUnits.isNotEmpty &&
          _selectedUnits.any((u) => u.model.team != tappedUnit.model.team)) {
        _addTarget(tappedUnit);
        return true;
      }
    } else {
      // PRODUCTION MODE: Check if we're tapping on an enemy unit
      if (_playerTeam != null && tappedUnit.model.team != _playerTeam) {
        // If we have selected units that can attack, set as target
        if (_selectedUnits.isNotEmpty) {
          _addTarget(tappedUnit);
          return true;
        }

        // Just show info about enemy unit
        tappedUnit.showUnitInfo();
        return true;
      }
    }

    // Handle selection of units
    if (developmentMode) {
      // DEVELOPMENT MODE: Allow selecting any unit regardless of team
      _handleUnitSelection(tappedUnit);
      return true;
    } else {
      // PRODUCTION MODE: Only allow selecting friendly units
      if (_playerTeam == null || tappedUnit.model.team == _playerTeam) {
        _handleUnitSelection(tappedUnit);
        return true;
      }
    }

    return false;
  }

  /// Clear ship selection
  void clearShipSelection() {
    for (final ship in _selectedShips) {
      ship.model.isSelected = false;
    }
    _selectedShips.clear();
    _lastSelectedShip = null;
  }

  /// Clear unit selection
  void clearUnitSelection() {
    for (final unit in _selectedUnits) {
      unit.setSelected(false);
    }
    _selectedUnits.clear();
    _lastSelectedUnit = null;
  }

  /// Add a unit as a target
  void _addTarget(UnitComponent unit) {
    if (!_targetedUnits.contains(unit)) {
      _targetedUnits.add(unit);
      unit.model.isTargeted = true;

      // Order selected units to attack this target
      _orderAttackOnTarget(unit);

      // Show feedback
      game.showUnitInfo(
          "Target acquired: ${unit.model.type.toString().split('.').last}");
    }
  }

  /// Remove a unit from targets
  void _removeTarget(UnitComponent unit) {
    if (_targetedUnits.contains(unit)) {
      _targetedUnits.remove(unit);
      unit.model.isTargeted = false;

      // Clear the target from selected units
      for (final selectedUnit in _selectedUnits) {
        if (selectedUnit.model.targetEnemy == unit.model) {
          selectedUnit.model.targetEnemy = null;
        }
      }

      game.showUnitInfo("Target removed");
    }
  }

  /// Clear all targets
  void clearTargets() {
    for (final unit in _targetedUnits) {
      unit.model.isTargeted = false;
    }
    _targetedUnits.clear();

    // Clear targets from selected units
    for (final selectedUnit in _selectedUnits) {
      selectedUnit.model.targetEnemy = null;
    }
  }

  /// Handle unit selection logic (extracted for clarity)
  void _handleUnitSelection(UnitComponent tappedUnit) {
    // Clear ship selection when selecting units
    clearShipSelection();

    // Check if shift key is held (multi-select) - for future implementation
    bool isMultiSelect = false;

    // If not multi-selecting, clear previous selection
    if (!isMultiSelect) {
      clearUnitSelection();
    }

    // Toggle selection state
    if (tappedUnit.model.isSelected) {
      tappedUnit.setSelected(false);
      _selectedUnits.remove(tappedUnit);
    } else {
      tappedUnit.setSelected(true);
      _selectedUnits.add(tappedUnit);
      _lastSelectedUnit = tappedUnit;
    }

    // Show unit info
    tappedUnit.showUnitInfo();
  }

  /// Handle tap on empty space
  bool handleEmptyTap(Vector2 worldPosition) {
    // If we're in targeting mode, cancel it
    if (_isSelectingTarget) {
      _isSelectingTarget = false;
      _attackRangeRadius = null;
      _attackRangeCenter = null;
      return true;
    }

    // If we have selected ships, move them (tap-to-move for ships)
    if (_selectedShips.isNotEmpty) {
      moveSelectedShips(worldPosition);
      return true;
    }

    // If we have selected units, move them
    if (_selectedUnits.isNotEmpty) {
      moveSelectedUnits(worldPosition);
      return true;
    }

    // Otherwise just clear selection and targets
    clearSelection();
    return false;
  }

  /// Move selected units to position
  void moveSelectedUnits(Vector2 worldTarget) {
    if (_selectedUnits.isEmpty) return;

    // Create destination marker
    game.createDestinationMarker(worldTarget);

    // Exit targeting mode if active
    _isSelectingTarget = false;
    _attackRangeRadius = null;
    _attackRangeCenter = null;

    // Clear targets when moving (units will focus on movement)
    clearTargets();

    // Calculate formation positions around the target
    final positions =
        _calculateFormationPositions(worldTarget, _selectedUnits.length);

    // Move all selected units to their formation positions
    for (int i = 0; i < _selectedUnits.length; i++) {
      final unit = _selectedUnits[i];
      final targetPos = i < positions.length ? positions[i] : worldTarget;
      unit.setTargetPosition(targetPos);

      // Force the unit to prioritize movement to the new target
      unit.model.forceRedirect = true;
    }
  }

  /// Move selected ships to position (tap-to-move for ships)
  void moveSelectedShips(Vector2 worldTarget) {
    if (_selectedShips.isEmpty) return;

    // Create destination marker
    game.createDestinationMarker(worldTarget);

    // Move all selected ships using their enhanced navigation
    for (final ship in _selectedShips) {
      ship.setTargetPosition(worldTarget);

      // Show navigation feedback
      String shipTeam =
          ship.model.team.toString().split('.').last.toUpperCase();
      game.showUnitInfo("$shipTeam turtle ship navigating to destination");
    }
  }

  /// Order selected units to attack a target
  void _orderAttackOnTarget(UnitComponent target) {
    if (_selectedUnits.isEmpty) return;

    // Filter units that can attack
    final attackingUnits =
        _selectedUnits.where((u) => u.model.attackPower > 0).toList();

    if (attackingUnits.isEmpty) {
      // If no units can attack, just move toward the target
      for (final unit in _selectedUnits) {
        unit.setTargetPosition(target.position);
      }
      return;
    }

    // For each attacking unit, set target enemy with player-initiated flag
    for (final unit in attackingUnits) {
      // Use the new setTargetEnemy method with player initiation bonus
      unit.model.setTargetEnemy(target.model, playerInitiated: true);

      // Set target position to move toward enemy
      unit.setTargetPosition(target.position);
      unit.model.forceRedirect = true;
    }

    // Non-attacking units should move close to the target
    final nonAttackingUnits =
        _selectedUnits.where((u) => u.model.attackPower <= 0).toList();
    for (final unit in nonAttackingUnits) {
      // Move to a position near the target
      final direction = (target.position - unit.position).normalized();
      final approachPosition =
          target.position - direction * 20; // Stay 20 units away

      unit.setTargetPosition(approachPosition);
      unit.model.forceRedirect = true;
    }
  }

  /// Attack the current target
  void _attackTarget() {
    if (_lastSelectedUnit == null || _targetUnit == null) return;

    // Check if target is in range
    final distance =
        _lastSelectedUnit!.position.distanceTo(_targetUnit!.position);

    // Get elevation for archers to adjust range
    double effectiveRange = _lastSelectedUnit!.model.attackRange;
    if (_lastSelectedUnit!.model.type == UnitType.archer) {
      try {
        final elevation = game.getElevationAt(_lastSelectedUnit!.position);
        if (elevation > 0.6) {
          effectiveRange = 100.0; // Extended range on high ground
        }
      } catch (e) {
        // Use default range if error occurs
      }
    }

    if (distance <= effectiveRange) {
      // Set attacking state
      _lastSelectedUnit!.model.state = UnitState.attacking;

      // For archers, create an arrow
      if (_lastSelectedUnit!.model.type == UnitType.archer) {
        final arrow = ArrowComponent(
          startPosition: _lastSelectedUnit!.position.clone(),
          targetPosition: _targetUnit!.position.clone(),
          team: _lastSelectedUnit!.model.team,
        );
        game.add(arrow);
      }

      // Apply damage to target
      final damage = _lastSelectedUnit!.model.attackPower * 0.5;
      _targetUnit!.model.health -= damage;

      // Show attack feedback
      game.showUnitInfo(
          "${_lastSelectedUnit!.model.type.toString().split('.').last} attacks enemy for ${damage.toStringAsFixed(1)} damage!");
    } else {
      // Target out of range - move toward target instead
      _lastSelectedUnit!.setTargetPosition(_targetUnit!.position);
      game.showUnitInfo("Target out of range - moving closer");
    }

    // Exit targeting mode
    _isSelectingTarget = false;
    _attackRangeRadius = null;
    _attackRangeCenter = null;
  }

  /// Select units in a box (still used for units, but ships use tap-to-select)
  void selectUnitsInBox(Vector2 screenStart, Vector2 screenEnd) {
    clearSelection();

    final minX = math.min(screenStart.x, screenEnd.x);
    final maxX = math.max(screenStart.x, screenEnd.x);
    final minY = math.min(screenStart.y, screenEnd.y);
    final maxY = math.max(screenStart.y, screenEnd.y);

    // DEVELOPMENT MODE: Allow selecting units from both teams
    if (developmentMode) {
      // Get player team from last spawned unit if not set
      if (_playerTeam == null) {
        final units = game.getAllUnits();
        if (units.isNotEmpty) {
          _playerTeam = units.last.model.team;
        }
      }
    } else {
      // PRODUCTION MODE: Get player team (last spawned unit's team)
      if (_playerTeam == null) {
        final units = game.getAllUnits();
        if (units.isNotEmpty) {
          _playerTeam = units.last.model.team;
        }
      }
    }

    const selectionBuffer = 10.0;

    // Select units (NOT ships - ships use tap-to-select only)
    for (final unit in game.getAllUnits()) {
      if (unit.model.health <= 0) continue;

      // DEVELOPMENT MODE: Allow selecting any unit
      // PRODUCTION MODE: Only select friendly units
      if (!developmentMode &&
          _playerTeam != null &&
          unit.model.team != _playerTeam) {
        continue;
      }

      // Convert unit world position to screen position for selection
      final unitScreenPos = game.worldToScreenPosition(unit.position);

      if (unitScreenPos.x >= minX - selectionBuffer &&
          unitScreenPos.x <= maxX + selectionBuffer &&
          unitScreenPos.y >= minY - selectionBuffer &&
          unitScreenPos.y <= maxY + selectionBuffer) {
        unit.setSelected(true);
        _selectedUnits.add(unit);
      }
    }

    // Set last selected unit if we selected any
    if (_selectedUnits.isNotEmpty) {
      _lastSelectedUnit = _selectedUnits.first;
    }
  }

  /// Clear all selections
  void clearSelection() {
    clearUnitSelection();
    clearShipSelection();
    _isSelectingTarget = false;
    _attackRangeRadius = null;
    _attackRangeCenter = null;

    // Also clear targets when clearing selection
    clearTargets();
  }

  /// Deploy unit from selected ship
  bool deployUnitFromShip(UnitType unitType) {
    if (_selectedShips.isEmpty) return false;

    final ship = _selectedShips.first;
    if (!ship.model.canDeployUnits()) return false;

    // Try to deploy the unit
    final deployedType = ship.deployUnit(unitType);
    if (deployedType == null) return false;

    // Get deployment position
    final deployPos = ship.getDeploymentPosition();
    if (deployPos == null) return false;

    // Create and spawn the unit
    game.spawnUnitAtPosition(deployedType, ship.model.team, deployPos);

    return true;
  }

  /// Calculate formation positions for multiple units
  List<Vector2> _calculateFormationPositions(Vector2 center, int unitCount) {
    if (unitCount <= 1) return [center];

    final positions = <Vector2>[];
    final spacing = 15.0; // Space between units

    // For small groups, use a simple line formation
    if (unitCount <= 5) {
      final lineWidth = (unitCount - 1) * spacing;
      final startX = center.x - lineWidth / 2;

      for (int i = 0; i < unitCount; i++) {
        positions.add(Vector2(startX + i * spacing, center.y));
      }
      return positions;
    }

    // For larger groups, use a circular formation
    final radius = spacing * unitCount / (2 * math.pi);
    for (int i = 0; i < unitCount; i++) {
      final angle = (i / unitCount) * 2 * math.pi;
      final x = center.x + radius * math.cos(angle);
      final y = center.y + radius * math.sin(angle);
      positions.add(Vector2(x, y));
    }

    return positions;
  }

  /// Render attack range indicator when in targeting mode
  void renderAttackRange(Canvas canvas) {
    if (!_isSelectingTarget ||
        _attackRangeRadius == null ||
        _attackRangeCenter == null) {
      return;
    }

    // Convert world position to screen position
    final screenPos = game.worldToScreenPosition(_attackRangeCenter!);
    final screenRadius = _attackRangeRadius! * game.zoomLevel;

    // Draw attack range circle
    final rangePaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final rangeBorderPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(
      Offset(screenPos.x, screenPos.y),
      screenRadius,
      rangePaint,
    );

    canvas.drawCircle(
      Offset(screenPos.x, screenPos.y),
      screenRadius,
      rangeBorderPaint,
    );
  }

  /// Get all selected objects info for UI (units + ships)
  List<Map<String, dynamic>> getSelectedObjectsInfo() {
    final List<Map<String, dynamic>> objectsInfo = [];

    // Add selected units
    for (final unit in _selectedUnits) {
      final healthPercent =
          (unit.model.health / unit.model.maxHealth * 100).toInt();
      final typeStr = unit.model.type.toString().split('.').last;
      final teamStr = unit.model.team.toString().split('.').last;

      objectsInfo.add({
        'type': 'UNIT',
        'subtype': typeStr.toUpperCase(),
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'hasFlag':
            unit.model.type == UnitType.captain && unit.model.hasPlantedFlag,
        'id': unit.model.id,
        'isTargeted': unit.model.isTargeted,
      });
    }

    // Add selected ships
    for (final ship in _selectedShips) {
      final healthPercent = (ship.model.healthPercent * 100).toInt();
      final teamStr = ship.model.team.toString().split('.').last;
      final cargo = ship.model.getAvailableUnits();

      objectsInfo.add({
        'type': 'SHIP',
        'subtype': 'TURTLE SHIP',
        'team': teamStr.toUpperCase(),
        'health': healthPercent,
        'status': ship.model.getStatusText(),
        'cargo': cargo,
        'canDeploy': ship.model.canDeployUnits(),
        'id': ship.model.id,
      });
    }

    return objectsInfo;
  }
}
