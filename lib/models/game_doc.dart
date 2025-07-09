// lib/models/game_doc.dart

/// A data model representing a game room stored in Firestore.
class GameDoc {
  /// The document ID, used as the room code (e.g. "ISL-ABC123").
  final String code;

  /// The current state of the room: "waiting", "active", "completed", or "expired".
  final String state;

  /// List of player UIDs in the room; length > 1 means an opponent joined.
  final List<String> players;

  /// When the room was created.
  final Timestamp createdAt;

  /// When the room will expire automatically.
  final Timestamp expiresAt;

  /// Optional custom settings for the room.
  final Map<String, dynamic>? settings;

  GameDoc({
    required this.code,
    required this.state,
    required this.players,
    required this.createdAt,
    required this.expiresAt,
    this.settings,
  });

  /// Constructs a GameDoc from a Firestore document snapshot.
  factory GameDoc.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data()!;
    return GameDoc(
      code: snap.id,
      state: data['state'] as String,
      players: List<String>.from(data['players'] ?? <String>[]),
      createdAt: data['createdAt'] as Timestamp,
      expiresAt: data['expiresAt'] as Timestamp,
      settings: data['settings'] as Map<String, dynamic>?,
    );
  }
}
