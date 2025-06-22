import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Represents a game room document in Firestore.
class GameDoc {
  final String code;
  final String state; // "waiting" | "active" | "completed" | "expired"
  final List<String> players;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final Map<String, dynamic>? settings;

  GameDoc({
    required this.code,
    required this.state,
    required this.players,
    required this.createdAt,
    required this.expiresAt,
    this.settings,
  });

  factory GameDoc.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data()!;
    return GameDoc(
      code: snap.id,
      state: data['state'] as String,
      players: List<String>.from(data['players'] ?? []),
      createdAt: data['createdAt'] as Timestamp,
      expiresAt: data['expiresAt'] as Timestamp,
      settings: data['settings'] as Map<String, dynamic>?,
    );
  }
}

/// Service to create, join, and watch game rooms in Firestore.
class RoomService {
  RoomService._();
  static final RoomService instance = RoomService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instance;

  /// Creates a new game room via Cloud Functions and returns the room code.
  Future<String> createRoom({Map<String, dynamic>? settings}) async {
    final callable = _functions.httpsCallable('createRoom');
    final result = await callable.call({'settings': settings ?? {}});
    return result.data['code'] as String;
  }

  /// Joins the current user into an existing room, flipping state to "active".
  Future<void> joinRoom(String code) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User not authenticated');
    final ref = _db.collection('games').doc(code);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Room $code not found');
      final data = snap.data()!;
      if (data['state'] != 'waiting') throw StateError('Room $code not open');
      final players = List<String>.from(data['players'] ?? []);
      if (players.contains(uid)) return;
      players.add(uid);
      tx.update(ref, {
        'players': players,
        'state': 'active',
      });
    });
  }

  /// Stream of room updates; emits a [GameDoc] whenever the room changes.
  Stream<GameDoc> watchRoom(String code) {
    return _db
        .collection('games')
        .doc(code)
        .snapshots()
        .where((snap) => snap.exists)
        .map((snap) => GameDoc.fromSnapshot(snap));
  }
}
