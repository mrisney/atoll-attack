// lib/ai/ai_player.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import '../models/unit_model.dart';
import '../models/ship_model.dart';
import '../constants/game_config.dart';
import '../utils/app_logger.dart';

enum AIDifficulty {
  easy,    // 1-2 second delays, basic strategies
  medium,  // 0.5-1 second delays, intermediate strategies  
  hard,    // 0.1-0.5 second delays, advanced strategies
}

class AIPlayer {
  final String playerId;
  final Team team;
  final AIDifficulty difficulty;
  final Function(String, Map<String, dynamic>) sendCommand;
  final Function() getGameState;
  
  Timer? _decisionTimer;
  DateTime _lastDecision = DateTime.now();
  
  // AI State
  AIStrategy _currentStrategy = AIStrategy.explore;
  Vector2? _primaryTarget;
  List<String> _controlledUnitIds = [];
  List<String> _controlledShipIds = [];
  
  AIPlayer({
    required this.playerId,
    required this.team,
    required this.difficulty,
    required this.sendCommand,
    required this.getGameState,
  });

  /// Start AI decision making
  void start() {
    final interval = _getDecisionInterval();
    _decisionTimer = Timer.periodic(interval, (_) => _makeDecision());
    AppLogger.debug('AI Player $playerId started with difficulty: $difficulty');
  }

  /// Stop AI decision making
  void stop() {
    _decisionTimer?.cancel();
    _decisionTimer = null;
  }

  /// Main AI decision loop
  void _makeDecision() {
    try {
      final gameState = getGameState();
      if (gameState == null) return;

      // Analyze current situation
      final situation = _analyzeSituation(gameState);
      
      // Update strategy based on situation
      _updateStrategy(situation);
      
      // Execute strategy
      _executeStrategy(situation);
      
      _lastDecision = DateTime.now();
    } catch (e) {
      AppLogger.error('AI decision error', e);
    }
  }

  /// Analyze current game situation
  AISituation _analyzeSituation(dynamic gameState) {
    // Extract game state information
    final myUnits = _getMyUnits(gameState);
    final enemyUnits = _getEnemyUnits(gameState);
    final myShips = _getMyShips(gameState);
    final apex = _getApexPosition(gameState);
    
    return AISituation(
      myUnits: myUnits,
      enemyUnits: enemyUnits,
      myShips: myShips,
      apexPosition: apex,
      myUnitCount: myUnits.length,
      enemyUnitCount: enemyUnits.length,
      averageMyHealth: _calculateAverageHealth(myUnits),
      averageEnemyHealth: _calculateAverageHealth(enemyUnits),
    );
  }

  /// Update AI strategy based on situation
  void _updateStrategy(AISituation situation) {
    // Strategy decision logic
    if (situation.myUnitCount == 0) {
      _currentStrategy = AIStrategy.spawn;
    } else if (situation.enemyUnitCount == 0) {
      _currentStrategy = AIStrategy.capture;
    } else if (situation.averageMyHealth < 0.3) {
      _currentStrategy = AIStrategy.heal;
    } else if (situation.myUnitCount > situation.enemyUnitCount * 1.5) {
      _currentStrategy = AIStrategy.attack;
    } else if (situation.myUnitCount < situation.enemyUnitCount * 0.7) {
      _currentStrategy = AIStrategy.defend;
    } else {
      _currentStrategy = AIStrategy.explore;
    }
  }

  /// Execute current strategy
  void _executeStrategy(AISituation situation) {
    switch (_currentStrategy) {
      case AIStrategy.spawn:
        _executeSpawnStrategy(situation);
        break;
      case AIStrategy.explore:
        _executeExploreStrategy(situation);
        break;
      case AIStrategy.attack:
        _executeAttackStrategy(situation);
        break;
      case AIStrategy.defend:
        _executeDefendStrategy(situation);
        break;
      case AIStrategy.heal:
        _executeHealStrategy(situation);
        break;
      case AIStrategy.capture:
        _executeCaptureStrategy(situation);
        break;
    }
  }

  /// Spawn units from ships
  void _executeSpawnStrategy(AISituation situation) {
    for (final ship in situation.myShips) {
      if (ship.canSpawnUnit()) {
        // Spawn based on difficulty and situation
        final unitType = _chooseUnitType(situation);
        _spawnUnit(ship.id, unitType);
      }
    }
  }

  /// Move units to explore the island
  void _executeExploreStrategy(AISituation situation) {
    final idleUnits = situation.myUnits.where((u) => u.state == UnitState.idle).toList();
    
    for (final unit in idleUnits) {
      if (situation.apexPosition != null) {
        _moveUnit(unit.id, situation.apexPosition!);
      }
    }
  }

  /// Attack enemy units
  void _executeAttackStrategy(AISituation situation) {
    final myUnits = situation.myUnits;
    final enemyUnits = situation.enemyUnits;
    
    for (final unit in myUnits) {
      final nearestEnemy = _findNearestEnemy(unit, enemyUnits);
      if (nearestEnemy != null) {
        _attackUnit(unit.id, nearestEnemy.id);
      }
    }
  }

  /// Defend strategic positions
  void _executeDefendStrategy(AISituation situation) {
    if (situation.apexPosition != null) {
      for (final unit in situation.myUnits) {
        _moveUnit(unit.id, situation.apexPosition!);
      }
    }
  }

  /// Send damaged units to ships for healing
  void _executeHealStrategy(AISituation situation) {
    final damagedUnits = situation.myUnits.where((u) => u.health < u.maxHealth * 0.7).toList();
    
    for (final unit in damagedUnits) {
      final nearestShip = _findNearestShip(unit, situation.myShips);
      if (nearestShip != null) {
        _sendUnitToShip(unit.id, nearestShip.id);
      }
    }
  }

  /// Capture the apex with captain
  void _executeCaptureStrategy(AISituation situation) {
    final captain = situation.myUnits.firstWhere(
      (u) => u.type == UnitType.captain,
      orElse: () => null,
    );
    
    if (captain != null && situation.apexPosition != null) {
      _moveUnit(captain.id, situation.apexPosition!);
    }
  }

  // Helper methods for AI commands
  void _spawnUnit(String shipId, UnitType unitType) {
    sendCommand('spawn_unit', {
      'ship_id': shipId,
      'unit_type': unitType.name,
      'team': team.name,
    });
  }

  void _moveUnit(String unitId, Vector2 position) {
    sendCommand('move_unit', {
      'unit_id': unitId,
      'target_x': position.x,
      'target_y': position.y,
    });
  }

  void _attackUnit(String attackerId, String targetId) {
    sendCommand('attack_unit', {
      'attacker_id': attackerId,
      'target_id': targetId,
    });
  }

  void _sendUnitToShip(String unitId, String shipId) {
    sendCommand('unit_to_ship', {
      'unit_id': unitId,
      'ship_id': shipId,
    });
  }

  // Utility methods
  Duration _getDecisionInterval() {
    switch (difficulty) {
      case AIDifficulty.easy:
        return Duration(milliseconds: 1000 + math.Random().nextInt(1000));
      case AIDifficulty.medium:
        return Duration(milliseconds: 500 + math.Random().nextInt(500));
      case AIDifficulty.hard:
        return Duration(milliseconds: 100 + math.Random().nextInt(400));
    }
  }

  UnitType _chooseUnitType(AISituation situation) {
    // Simple unit composition logic
    final random = math.Random();
    if (situation.myUnits.isEmpty) {
      return UnitType.captain; // Always spawn captain first
    } else if (random.nextDouble() < 0.3) {
      return UnitType.archer;
    } else {
      return UnitType.swordsman;
    }
  }

  // Game state extraction methods
  List<UnitModel> _getMyUnits(dynamic gameState) {
    // Extract units belonging to this AI player
    // Implementation depends on your game state structure
    return [];
  }

  List<UnitModel> _getEnemyUnits(dynamic gameState) {
    // Extract enemy units
    return [];
  }

  List<ShipModel> _getMyShips(dynamic gameState) {
    // Extract ships belonging to this AI player
    return [];
  }

  Vector2? _getApexPosition(dynamic gameState) {
    // Extract apex position from game state
    return null;
  }

  double _calculateAverageHealth(List<UnitModel> units) {
    if (units.isEmpty) return 0.0;
    return units.map((u) => u.health / u.maxHealth).reduce((a, b) => a + b) / units.length;
  }

  UnitModel? _findNearestEnemy(UnitModel unit, List<UnitModel> enemies) {
    if (enemies.isEmpty) return null;
    
    UnitModel? nearest;
    double nearestDistance = double.infinity;
    
    for (final enemy in enemies) {
      final distance = unit.position.distanceTo(enemy.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = enemy;
      }
    }
    
    return nearest;
  }

  ShipModel? _findNearestShip(UnitModel unit, List<ShipModel> ships) {
    if (ships.isEmpty) return null;
    
    ShipModel? nearest;
    double nearestDistance = double.infinity;
    
    for (final ship in ships) {
      final distance = unit.position.distanceTo(ship.position);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = ship;
      }
    }
    
    return nearest;
  }
}

enum AIStrategy {
  spawn,    // Spawn units from ships
  explore,  // Move units toward objectives
  attack,   // Aggressive combat
  defend,   // Defensive positioning
  heal,     // Send units for healing
  capture,  // Capture victory points
}

class AISituation {
  final List<UnitModel> myUnits;
  final List<UnitModel> enemyUnits;
  final List<ShipModel> myShips;
  final Vector2? apexPosition;
  final int myUnitCount;
  final int enemyUnitCount;
  final double averageMyHealth;
  final double averageEnemyHealth;

  AISituation({
    required this.myUnits,
    required this.enemyUnits,
    required this.myShips,
    required this.apexPosition,
    required this.myUnitCount,
    required this.enemyUnitCount,
    required this.averageMyHealth,
    required this.averageEnemyHealth,
  });
}
