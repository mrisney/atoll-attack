// lib/models/ship_snapshot.dart
import 'package:flame/components.dart';
import '../models/ship_model.dart';
import '../models/unit_model.dart';

class ShipSnapshot {
  final String id;
  final String teamId; // Using playerId for consistency
  final double x;
  final double y;
  final double velocityX;
  final double velocityY;
  final double? targetX;
  final double? targetY;
  final List<String>? navigationPath; // Serialized waypoints
  final bool isSelected;
  final bool isAtShore;
  final bool isDeploying;
  final bool isStuck;
  final bool isNavigating;
  final double health;
  final double maxHealth;
  final double cannonCooldown;
  final List<String> cargo; // Unit types as strings
  final bool hasSail;
  final bool usingPaddles;

  ShipSnapshot({
    required this.id,
    required this.teamId,
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    this.targetX,
    this.targetY,
    this.navigationPath,
    required this.isSelected,
    required this.isAtShore,
    required this.isDeploying,
    required this.isStuck,
    required this.isNavigating,
    required this.health,
    required this.maxHealth,
    required this.cannonCooldown,
    required this.cargo,
    required this.hasSail,
    required this.usingPaddles,
  });

  factory ShipSnapshot.fromModel(ShipModel model) {
    return ShipSnapshot(
      id: model.id,
      teamId: model.team == Team.blue ? 'blue' : 'red',
      x: model.position.x,
      y: model.position.y,
      velocityX: model.velocity.x,
      velocityY: model.velocity.y,
      targetX: model.targetPosition?.x,
      targetY: model.targetPosition?.y,
      navigationPath:
          model.navigationPath?.map((v) => '${v.x},${v.y}').toList(),
      isSelected: model.isSelected,
      isAtShore: model.isAtShore,
      isDeploying: model.isDeploying,
      isStuck: model.isStuck,
      isNavigating: model.isNavigating,
      health: model.health,
      maxHealth: model.maxHealth,
      cannonCooldown: model.cannonCooldown,
      cargo: model.cargo.map((type) => type.name).toList(),
      hasSail: model.hasSail,
      usingPaddles: model.usingPaddles,
    );
  }

  ShipModel toModel({
    required bool Function(Vector2)? isOnLandCallback,
    required bool Function(Vector2)? isNearShoreCallback,
  }) {
    final model = ShipModel(
      id: id,
      team: teamId == 'blue' ? Team.blue : Team.red,
      position: Vector2(x, y),
      velocity: Vector2(velocityX, velocityY),
      targetPosition: targetX != null && targetY != null
          ? Vector2(targetX!, targetY!)
          : null,
      isOnLandCallback: isOnLandCallback,
      isNearShoreCallback: isNearShoreCallback,
    );

    // Restore state
    model.isSelected = isSelected;
    model.isAtShore = isAtShore;
    model.isDeploying = isDeploying;
    model.isStuck = isStuck;
    model.isNavigating = isNavigating;
    model.health = health;
    model.cannonCooldown = cannonCooldown;
    model.hasSail = hasSail;
    model.usingPaddles = usingPaddles;

    // Restore cargo
    model.cargo.clear();
    for (final cargoType in cargo) {
      model.cargo.add(UnitType.values.byName(cargoType));
    }

    // Restore navigation path
    if (navigationPath != null) {
      model.navigationPath = navigationPath!.map((coord) {
        final parts = coord.split(',');
        return Vector2(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();
    }

    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teamId': teamId,
      'position': {'x': x, 'y': y},
      'velocity': {'x': velocityX, 'y': velocityY},
      'target': targetX != null ? {'x': targetX, 'y': targetY} : null,
      'navigationPath': navigationPath,
      'isSelected': isSelected,
      'isAtShore': isAtShore,
      'isDeploying': isDeploying,
      'isStuck': isStuck,
      'isNavigating': isNavigating,
      'health': health,
      'maxHealth': maxHealth,
      'cannonCooldown': cannonCooldown,
      'cargo': cargo,
      'hasSail': hasSail,
      'usingPaddles': usingPaddles,
    };
  }

  factory ShipSnapshot.fromJson(Map<String, dynamic> json) {
    return ShipSnapshot(
      id: json['id'],
      teamId: json['teamId'],
      x: json['position']['x'].toDouble(),
      y: json['position']['y'].toDouble(),
      velocityX: json['velocity']['x'].toDouble(),
      velocityY: json['velocity']['y'].toDouble(),
      targetX: json['target']?['x']?.toDouble(),
      targetY: json['target']?['y']?.toDouble(),
      navigationPath: json['navigationPath'] != null
          ? List<String>.from(json['navigationPath'])
          : null,
      isSelected: json['isSelected'],
      isAtShore: json['isAtShore'],
      isDeploying: json['isDeploying'],
      isStuck: json['isStuck'],
      isNavigating: json['isNavigating'],
      health: json['health'].toDouble(),
      maxHealth: json['maxHealth'].toDouble(),
      cannonCooldown: json['cannonCooldown'].toDouble(),
      cargo: List<String>.from(json['cargo']),
      hasSail: json['hasSail'],
      usingPaddles: json['usingPaddles'],
    );
  }
}
