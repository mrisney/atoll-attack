// lib/models/unit_snapshot.dart
import 'package:flame/components.dart';
import 'unit_model.dart';

class UnitSnapshot {
  final String id;
  final String playerId;
  final UnitType type;
  final UnitState state;
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final double targetX;
  final double targetY;
  final double health;
  final double maxHealth;
  final bool hasPlantedFlag;
  final bool isSelected;
  final bool isTargeted;
  final String? targetEnemyId;
  final double attackCooldown;
  final bool isInCombat;
  final bool isRaisingFlag;
  final double flagRaiseProgress;

  UnitSnapshot({
    required this.id,
    required this.playerId,
    required this.type,
    required this.state,
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.targetX,
    required this.targetY,
    required this.health,
    required this.maxHealth,
    required this.hasPlantedFlag,
    required this.isSelected,
    required this.isTargeted,
    this.targetEnemyId,
    required this.attackCooldown,
    required this.isInCombat,
    required this.isRaisingFlag,
    required this.flagRaiseProgress,
  });

  factory UnitSnapshot.fromModel(UnitModel model) {
    return UnitSnapshot(
      id: model.id,
      playerId: model.playerId,
      type: model.type,
      state: model.state,
      x: model.position.x,
      y: model.position.y,
      velocityX: model.velocity.x,
      velocityY: model.velocity.y,
      targetX: model.targetPosition.x,
      targetY: model.targetPosition.y,
      health: model.health,
      maxHealth: model.maxHealth,
      hasPlantedFlag: model.hasPlantedFlag,
      isSelected: model.isSelected,
      isTargeted: model.isTargeted,
      targetEnemyId: model.targetEnemy?.id,
      attackCooldown: model.attackCooldown,
      isInCombat: model.isInCombat,
      isRaisingFlag: model.isRaisingFlag,
      flagRaiseProgress: model.flagRaiseProgress,
    );
  }

  UnitModel toModel({
    required bool Function(Vector2)? isOnLandCallback,
    required double Function(Vector2)? getTerrainSpeedCallback,
  }) {
    final model = UnitModel(
      id: id,
      type: type,
      position: Vector2(x, y),
      playerId: playerId,
      state: state,
      velocity: Vector2(velocityX, velocityY),
      targetPosition: Vector2(targetX, targetY),
      isSelected: isSelected,
      isTargeted: isTargeted,
      isOnLandCallback: isOnLandCallback,
      getTerrainSpeedCallback: getTerrainSpeedCallback,
    );

    // Restore combat state
    model.health = health;
    model.hasPlantedFlag = hasPlantedFlag;
    model.attackCooldown = attackCooldown;
    model.isInCombat = isInCombat;
    model.isRaisingFlag = isRaisingFlag;
    model.flagRaiseProgress = flagRaiseProgress;

    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerId': playerId,
      'type': type.name,
      'state': state.name,
      'position': {'x': x, 'y': y},
      'velocity': {'x': velocityX, 'y': velocityY},
      'target': {'x': targetX, 'y': targetY},
      'health': health,
      'maxHealth': maxHealth,
      'hasPlantedFlag': hasPlantedFlag,
      'isSelected': isSelected,
      'isTargeted': isTargeted,
      'targetEnemyId': targetEnemyId,
      'attackCooldown': attackCooldown,
      'isInCombat': isInCombat,
      'isRaisingFlag': isRaisingFlag,
      'flagRaiseProgress': flagRaiseProgress,
    };
  }

  factory UnitSnapshot.fromJson(Map<String, dynamic> json) {
    return UnitSnapshot(
      id: json['id'],
      playerId: json['playerId'],
      type: UnitType.values.byName(json['type']),
      state: UnitState.values.byName(json['state']),
      x: json['position']['x'].toDouble(),
      y: json['position']['y'].toDouble(),
      velocityX: json['velocity']['x'].toDouble(),
      velocityY: json['velocity']['y'].toDouble(),
      targetX: json['target']['x'].toDouble(),
      targetY: json['target']['y'].toDouble(),
      health: json['health'].toDouble(),
      maxHealth: json['maxHealth'].toDouble(),
      hasPlantedFlag: json['hasPlantedFlag'],
      isSelected: json['isSelected'],
      isTargeted: json['isTargeted'],
      targetEnemyId: json['targetEnemyId'],
      attackCooldown: json['attackCooldown'].toDouble(),
      isInCombat: json['isInCombat'],
      isRaisingFlag: json['isRaisingFlag'],
      flagRaiseProgress: json['flagRaiseProgress'].toDouble(),
    );
  }
}
