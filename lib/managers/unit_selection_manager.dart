import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/unit_model.dart';
import '../game/unit_component.dart';
import '../game/arrow_component.dart';
import '../game/island_game.dart';

/// Manages unit selection, targeting, and attack logic
class UnitSelectionManager {
  // Selected units
  final List<UnitComponent> _selectedUnits = [];
  
  // Reference to game
  final IslandGame game;
  
  // Selection state tracking
  UnitComponent? _lastSelectedUnit;
  UnitComponent? _targetUnit;
  bool _isSelectingTarget = false;
  
  // Attack range visualization
  double? _attackRangeRadius;
  Vector2? _attackRangeCenter;
  
  // Team that player is controlling
  Team? _playerTeam;
  
  UnitSelectionManager(this.game);
  
  // Getters
  List<UnitComponent> get selectedUnits => List.unmodifiable(_selectedUnits);
  bool get hasSelection => _selectedUnits.isNotEmpty;
  bool get isSelectingTarget => _isSelectingTarget;
  UnitComponent? get lastSelectedUnit => _lastSelectedUnit;
  Team? get playerTeam => _playerTeam;
  
  /// Set the player's team
  void setPlayerTeam(Team team) {
    _playerTeam = team;
  }
  
  /// Handle tap on a unit
  bool handleUnitTap(UnitComponent tappedUnit) {
    // If we're in targeting mode and tap on a valid target
    if (_isSelectingTarget) {
      // Check if tapped unit is a valid target (enemy unit)
      if (_lastSelectedUnit != null && tappedUnit.model.team != _lastSelectedUnit!.model.team) {
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
    
    // Check if we're tapping on an enemy unit
    if (_playerTeam != null && tappedUnit.model.team != _playerTeam) {
      // If we have selected units that can attack, order them to attack this enemy
      if (_selectedUnits.isNotEmpty) {
        _orderAttackOnTarget(tappedUnit);
        return true;
      }
      
      // Just show info about enemy unit
      tappedUnit.showUnitInfo();
      return true;
    }
    
    // Handle selection of friendly units
    if (_playerTeam == null || tappedUnit.model.team == _playerTeam) {
      // Check if shift key is held (multi-select)
      bool isMultiSelect = false; // This would come from keyboard input
      
      // If not multi-selecting, clear previous selection
      if (!isMultiSelect) {
        clearSelection();
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
      
      return true;
    }
    
    return false;
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
    
    // If we have selected units, move them
    if (_selectedUnits.isNotEmpty) {
      moveSelectedUnits(worldPosition);
      return true;
    }
    
    // Otherwise just clear selection
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
    
    // Calculate formation positions around the target
    final positions = _calculateFormationPositions(worldTarget, _selectedUnits.length);
    
    // Move all selected units to their formation positions
    for (int i = 0; i < _selectedUnits.length; i++) {
      final unit = _selectedUnits[i];
      final targetPos = i < positions.length ? positions[i] : worldTarget;
      unit.setTargetPosition(targetPos);
      
      // Force the unit to prioritize movement to the new target
      unit.model.forceRedirect = true;
    }
  }
  
  /// Order selected units to attack a target
  void _orderAttackOnTarget(UnitComponent target) {
    if (_selectedUnits.isEmpty) return;
    
    // Filter units that can attack
    final attackingUnits = _selectedUnits.where((u) => u.model.attackPower > 0).toList();
    
    if (attackingUnits.isEmpty) {
      // If no units can attack, just move toward the target
      for (final unit in _selectedUnits) {
        unit.setTargetPosition(target.position);
      }
      return;
    }
    
    // For each attacking unit, set target enemy
    for (final unit in attackingUnits) {
      unit.setTargetEnemy(target.model);
      
      // Calculate effective attack range
      double effectiveRange = unit.model.attackRange;
      if (unit.model.type == UnitType.archer) {
        try {
          final elevation = game.getElevationAt(unit.position);
          if (elevation > 0.6) {
            effectiveRange = 100.0; // Extended range on high ground
          }
        } catch (e) {
          // Use default range if error occurs
        }
      }
      
      // Calculate distance to target
      final distance = unit.position.distanceTo(target.position);
      
      // If not in range, move to get in range
      if (distance > effectiveRange) {
        // Calculate approach position based on unit type
        final direction = (target.position - unit.position).normalized();
        
        // Archers should stay at maximum range
        // Swordsmen should get close
        final approachDistance = unit.model.type == UnitType.archer 
            ? effectiveRange * 0.9  // Archers stay at 90% of max range
            : unit.model.radius * 2; // Melee units get very close
            
        final approachPosition = target.position - direction * approachDistance;
        
        unit.setTargetPosition(approachPosition);
        unit.model.forceRedirect = true;
      }
    }
    
    // Non-attacking units should move close to the target
    final nonAttackingUnits = _selectedUnits.where((u) => u.model.attackPower <= 0).toList();
    for (final unit in nonAttackingUnits) {
      // Move to a position near the target
      final direction = (target.position - unit.position).normalized();
      final approachPosition = target.position - direction * 20; // Stay 20 units away
      
      unit.setTargetPosition(approachPosition);
      unit.model.forceRedirect = true;
    }
    
    // Show feedback to the player
    if (attackingUnits.isNotEmpty) {
      game.showUnitInfo("${attackingUnits.length} units attacking enemy ${target.model.type.toString().split('.').last}");
    }
  }
  
  /// Attack the current target
  void _attackTarget() {
    if (_lastSelectedUnit == null || _targetUnit == null) return;
    
    // Check if target is in range
    final distance = _lastSelectedUnit!.position.distanceTo(_targetUnit!.position);
    
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
      game.showUnitInfo("${_lastSelectedUnit!.model.type.toString().split('.').last} attacks enemy for ${damage.toStringAsFixed(1)} damage!");
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
  
  /// Select units in a box
  void selectUnitsInBox(Vector2 screenStart, Vector2 screenEnd) {
    clearSelection();
    
    final minX = math.min(screenStart.x, screenEnd.x);
    final maxX = math.max(screenStart.x, screenEnd.x);
    final minY = math.min(screenStart.y, screenEnd.y);
    final maxY = math.max(screenStart.y, screenEnd.y);
    
    // Get player team (last spawned unit's team)
    if (_playerTeam == null) {
      final units = game.getAllUnits();
      if (units.isNotEmpty) {
        _playerTeam = units.last.model.team;
      }
    }
    
    const selectionBuffer = 10.0;
    
    for (final unit in game.getAllUnits()) {
      if (unit.model.health <= 0) continue;
      if (_playerTeam != null && unit.model.team != _playerTeam) continue;
      
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
    for (final unit in _selectedUnits) {
      unit.setSelected(false);
    }
    _selectedUnits.clear();
    _lastSelectedUnit = null;
    _isSelectingTarget = false;
    _attackRangeRadius = null;
    _attackRangeCenter = null;
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
    if (!_isSelectingTarget || _attackRangeRadius == null || _attackRangeCenter == null) {
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
}