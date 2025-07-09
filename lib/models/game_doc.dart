// lib/models/game_doc.dart

/// A data model representing a game room.
class GameDoc {
  /// The document ID, used as the room code (e.g. "ISL-ABC123").
  final String code;

  /// The current state of the room: "waiting", "active", "completed", or "expired".
  final String state;

  /// When the room was created
  final DateTime createdAt;

  /// When the room expires
  final DateTime expiresAt;

  /// List of player IDs in the room
  final List<String> players;

  /// Maximum number of players allowed
  final int maxPlayers;

  const GameDoc({
    required this.code,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
    required this.players,
    this.maxPlayers = 2,
  });

  /// Create GameDoc from Map data
  factory GameDoc.fromMap(Map<String, dynamic> data, String code) {
    return GameDoc(
      code: code,
      state: data['state'] as String? ?? 'waiting',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int? ?? 0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int? ?? 0),
      players: List<String>.from(data['players'] as List? ?? []),
      maxPlayers: data['maxPlayers'] as int? ?? 2,
    );
  }

  /// Convert GameDoc to Map
  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'state': state,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'players': players,
      'maxPlayers': maxPlayers,
    };
  }

  /// Check if the room is full
  bool get isFull => players.length >= maxPlayers;

  /// Check if the room is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the room is active
  bool get isActive => state == 'active';

  /// Check if the room is waiting for players
  bool get isWaiting => state == 'waiting';
}
