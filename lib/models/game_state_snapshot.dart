// lib/models/game_state_snapshot.dart
import 'unit_snapshot.dart';
import 'ship_snapshot.dart';
import 'player_model.dart';
import '../game/island_game.dart';

class GameStateSnapshot {
  final Map<String, PlayerSnapshot> players;
  final List<UnitSnapshot> units;
  final List<ShipSnapshot> ships;
  final DateTime timestamp;
  final String? victoryPlayerId;
  final bool isVictoryAchieved;
  final String? currentTurnPlayerId;

  GameStateSnapshot({
    required this.players,
    required this.units,
    required this.ships,
    required this.timestamp,
    this.victoryPlayerId,
    required this.isVictoryAchieved,
    this.currentTurnPlayerId,
  });

  factory GameStateSnapshot.fromGame(IslandGame game) {
    // Create player snapshots
    final playerSnapshots = <String, PlayerSnapshot>{};
    for (final entry in game.players.entries) {
      playerSnapshots[entry.key] = PlayerSnapshot.fromPlayer(entry.value);
    }

    // Create unit snapshots
    final unitSnapshots = game
        .getAllUnits()
        .map((unit) => UnitSnapshot.fromModel(unit.model))
        .toList();

    // Create ship snapshots
    final shipSnapshots = game
        .getAllShips()
        .map((ship) => ShipSnapshot.fromModel(ship.model))
        .toList();

    return GameStateSnapshot(
      players: playerSnapshots,
      units: unitSnapshots,
      ships: shipSnapshots,
      timestamp: DateTime.now(),
      victoryPlayerId: game.isVictoryAchieved()
          ? (game.blueUnitCount > 0 ? 'blue' : 'red')
          : null,
      isVictoryAchieved: game.isVictoryAchieved(),
      currentTurnPlayerId: null, // Will be used for turn-based multiplayer
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'players': players.map((k, v) => MapEntry(k, v.toJson())),
      'units': units.map((u) => u.toJson()).toList(),
      'ships': ships.map((s) => s.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'victoryPlayerId': victoryPlayerId,
      'isVictoryAchieved': isVictoryAchieved,
      'currentTurnPlayerId': currentTurnPlayerId,
    };
  }

  factory GameStateSnapshot.fromJson(Map<String, dynamic> json) {
    return GameStateSnapshot(
      players: (json['players'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, PlayerSnapshot.fromJson(v))),
      units:
          (json['units'] as List).map((u) => UnitSnapshot.fromJson(u)).toList(),
      ships:
          (json['ships'] as List).map((s) => ShipSnapshot.fromJson(s)).toList(),
      timestamp: DateTime.parse(json['timestamp']),
      victoryPlayerId: json['victoryPlayerId'],
      isVictoryAchieved: json['isVictoryAchieved'],
      currentTurnPlayerId: json['currentTurnPlayerId'],
    );
  }
}

class PlayerSnapshot {
  final String id;
  final String name;
  final int unitsRemaining;
  final Map<String, int> spawnedUnits;

  PlayerSnapshot({
    required this.id,
    required this.name,
    required this.unitsRemaining,
    required this.spawnedUnits,
  });

  factory PlayerSnapshot.fromPlayer(Player player) {
    return PlayerSnapshot(
      id: player.id,
      name: player.name,
      unitsRemaining: player.unitsRemaining,
      spawnedUnits:
          Map.from(player.spawnedUnits.map((k, v) => MapEntry(k.name, v))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unitsRemaining': unitsRemaining,
      'spawnedUnits': spawnedUnits,
    };
  }

  factory PlayerSnapshot.fromJson(Map<String, dynamic> json) {
    return PlayerSnapshot(
      id: json['id'],
      name: json['name'],
      unitsRemaining: json['unitsRemaining'],
      spawnedUnits: Map<String, int>.from(json['spawnedUnits']),
    );
  }
}
