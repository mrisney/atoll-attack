// lib/models/player_model.dart
import 'package:flutter/material.dart';
import 'unit_model.dart';
import '../constants/game_config.dart';

class Player {
  final String id;
  final String name;
  final Color color;
  final Color lightColor;
  final Color darkColor;
  int unitsRemaining;

  final Map<UnitType, int> spawnedUnits = {
    UnitType.captain: 0,
    UnitType.archer: 0,
    UnitType.swordsman: 0,
  };

  Player({
    required this.id,
    required this.name,
    required this.color,
    Color? lightColor,
    Color? darkColor,
    this.unitsRemaining = kTotalUnitsPerTeam,
  })  : lightColor = lightColor ?? color.withOpacity(0.3),
        darkColor = darkColor ?? color.withOpacity(0.7);

  bool canSpawnUnit(UnitType type) {
    if (unitsRemaining <= 0) return false;

    switch (type) {
      case UnitType.captain:
        return spawnedUnits[type]! < kMaxCaptainsPerTeam;
      case UnitType.archer:
        return spawnedUnits[type]! < kMaxArchersPerTeam;
      case UnitType.swordsman:
        return spawnedUnits[type]! < kMaxSwordsmenPerTeam;
    }
  }

  int getRemainingUnits(UnitType type) {
    final maxUnits = switch (type) {
      UnitType.captain => kMaxCaptainsPerTeam,
      UnitType.archer => kMaxArchersPerTeam,
      UnitType.swordsman => kMaxSwordsmenPerTeam,
    };
    return maxUnits - (spawnedUnits[type] ?? 0);
  }

  void reset() {
    unitsRemaining = kTotalUnitsPerTeam;
    spawnedUnits[UnitType.captain] = 0;
    spawnedUnits[UnitType.archer] = 0;
    spawnedUnits[UnitType.swordsman] = 0;
  }
}

class Players {
  static final blue = Player(
    id: 'blue',
    name: 'Blue Team',
    color: Colors.blue,
    lightColor: Colors.blue.shade300,
    darkColor: Colors.blue.shade700,
  );

  static final red = Player(
    id: 'red',
    name: 'Red Team',
    color: Colors.red,
    lightColor: Colors.red.shade300,
    darkColor: Colors.red.shade700,
  );

  static void resetAll() {
    blue.reset();
    red.reset();
  }
}
