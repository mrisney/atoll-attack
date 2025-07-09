// lib/models/game_command.dart
import 'package:flame/components.dart';
import 'unit_model.dart';

/// Base class for all game commands that can be synchronized between players
abstract class GameCommand {
  final String commandId;
  final String playerId;
  final DateTime timestamp;
  final String commandType;

  GameCommand({
    required this.commandId,
    required this.playerId,
    required this.commandType,
  }) : timestamp = DateTime.now();

  /// Convert command to JSON for network transmission
  Map<String, dynamic> toJson();

  /// Create command from JSON received from network
  static GameCommand fromJson(Map<String, dynamic> json) {
    final type = json['commandType'] as String;
    
    switch (type) {
      case 'unit_move':
        return UnitMoveCommand.fromJson(json);
      case 'unit_spawn':
        return UnitSpawnCommand.fromJson(json);
      case 'unit_attack':
        return UnitAttackCommand.fromJson(json);
      case 'ship_move':
        return ShipMoveCommand.fromJson(json);
      case 'ship_deploy':
        return ShipDeployCommand.fromJson(json);
      case 'unit_board_ship':
        return UnitBoardShipCommand.fromJson(json);
      case 'flag_raise':
        return FlagRaiseCommand.fromJson(json);
      default:
        throw ArgumentError('Unknown command type: $type');
    }
  }
}

/// Command for moving units to a target position
class UnitMoveCommand extends GameCommand {
  final List<String> unitIds;
  final Vector2 targetPosition;
  final bool isAttackMove; // True if this is an attack-move command

  UnitMoveCommand({
    required String commandId,
    required String playerId,
    required this.unitIds,
    required this.targetPosition,
    this.isAttackMove = false,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'unit_move',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'unitIds': unitIds,
      'targetPosition': {
        'x': targetPosition.x,
        'y': targetPosition.y,
      },
      'isAttackMove': isAttackMove,
    };
  }

  static UnitMoveCommand fromJson(Map<String, dynamic> json) {
    final targetPos = json['targetPosition'] as Map<String, dynamic>;
    return UnitMoveCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      unitIds: List<String>.from(json['unitIds']),
      targetPosition: Vector2(
        (targetPos['x'] as num).toDouble(),
        (targetPos['y'] as num).toDouble(),
      ),
      isAttackMove: json['isAttackMove'] ?? false,
    );
  }
}

/// Command for spawning a unit from a ship
class UnitSpawnCommand extends GameCommand {
  final String shipId;
  final UnitType unitType;
  final Vector2 spawnPosition;

  UnitSpawnCommand({
    required String commandId,
    required String playerId,
    required this.shipId,
    required this.unitType,
    required this.spawnPosition,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'unit_spawn',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'shipId': shipId,
      'unitType': unitType.name,
      'spawnPosition': {
        'x': spawnPosition.x,
        'y': spawnPosition.y,
      },
    };
  }

  static UnitSpawnCommand fromJson(Map<String, dynamic> json) {
    final spawnPos = json['spawnPosition'] as Map<String, dynamic>;
    return UnitSpawnCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      shipId: json['shipId'],
      unitType: UnitType.values.firstWhere(
        (e) => e.name == json['unitType'],
      ),
      spawnPosition: Vector2(
        (spawnPos['x'] as num).toDouble(),
        (spawnPos['y'] as num).toDouble(),
      ),
    );
  }
}

/// Command for unit attacking another unit
class UnitAttackCommand extends GameCommand {
  final String attackerUnitId;
  final String targetUnitId;
  final bool isPlayerInitiated; // True if player explicitly ordered this attack

  UnitAttackCommand({
    required String commandId,
    required String playerId,
    required this.attackerUnitId,
    required this.targetUnitId,
    this.isPlayerInitiated = false,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'unit_attack',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'attackerUnitId': attackerUnitId,
      'targetUnitId': targetUnitId,
      'isPlayerInitiated': isPlayerInitiated,
    };
  }

  static UnitAttackCommand fromJson(Map<String, dynamic> json) {
    return UnitAttackCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      attackerUnitId: json['attackerUnitId'],
      targetUnitId: json['targetUnitId'],
      isPlayerInitiated: json['isPlayerInitiated'] ?? false,
    );
  }
}

/// Command for moving ships
class ShipMoveCommand extends GameCommand {
  final String shipId;
  final Vector2 targetPosition;

  ShipMoveCommand({
    required String commandId,
    required String playerId,
    required this.shipId,
    required this.targetPosition,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'ship_move',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'shipId': shipId,
      'targetPosition': {
        'x': targetPosition.x,
        'y': targetPosition.y,
      },
    };
  }

  static ShipMoveCommand fromJson(Map<String, dynamic> json) {
    final targetPos = json['targetPosition'] as Map<String, dynamic>;
    return ShipMoveCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      shipId: json['shipId'],
      targetPosition: Vector2(
        (targetPos['x'] as num).toDouble(),
        (targetPos['y'] as num).toDouble(),
      ),
    );
  }
}

/// Command for deploying units from ship
class ShipDeployCommand extends GameCommand {
  final String shipId;
  final UnitType unitType;

  ShipDeployCommand({
    required String commandId,
    required String playerId,
    required this.shipId,
    required this.unitType,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'ship_deploy',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'shipId': shipId,
      'unitType': unitType.name,
    };
  }

  static ShipDeployCommand fromJson(Map<String, dynamic> json) {
    return ShipDeployCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      shipId: json['shipId'],
      unitType: UnitType.values.firstWhere(
        (e) => e.name == json['unitType'],
      ),
    );
  }
}

/// Command for units boarding ships for healing
class UnitBoardShipCommand extends GameCommand {
  final List<String> unitIds;
  final String shipId;

  UnitBoardShipCommand({
    required String commandId,
    required String playerId,
    required this.unitIds,
    required this.shipId,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'unit_board_ship',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'unitIds': unitIds,
      'shipId': shipId,
    };
  }

  static UnitBoardShipCommand fromJson(Map<String, dynamic> json) {
    return UnitBoardShipCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      unitIds: List<String>.from(json['unitIds']),
      shipId: json['shipId'],
    );
  }
}

/// Command for captain raising flag at apex
class FlagRaiseCommand extends GameCommand {
  final String captainUnitId;
  final Vector2 apexPosition;

  FlagRaiseCommand({
    required String commandId,
    required String playerId,
    required this.captainUnitId,
    required this.apexPosition,
  }) : super(
          commandId: commandId,
          playerId: playerId,
          commandType: 'flag_raise',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'commandId': commandId,
      'playerId': playerId,
      'commandType': commandType,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'captainUnitId': captainUnitId,
      'apexPosition': {
        'x': apexPosition.x,
        'y': apexPosition.y,
      },
    };
  }

  static FlagRaiseCommand fromJson(Map<String, dynamic> json) {
    final apexPos = json['apexPosition'] as Map<String, dynamic>;
    return FlagRaiseCommand(
      commandId: json['commandId'],
      playerId: json['playerId'],
      captainUnitId: json['captainUnitId'],
      apexPosition: Vector2(
        (apexPos['x'] as num).toDouble(),
        (apexPos['y'] as num).toDouble(),
      ),
    );
  }
}
