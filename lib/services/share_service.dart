// lib/services/share_service.dart
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/game_doc.dart';
import 'package:logger/logger.dart';

final logger = Logger();

/// A single service for room management (create/join/watch), invite sharing,
/// and listening for join events.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  // Firebase clients
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Creates a new game room via Cloud Functions and returns its code.
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
      if (!players.contains(uid)) {
        players.add(uid);
        tx.update(ref, {
          'players': players,
          'state': 'active',
        });
      }
    });
  }

  /// Streams room updates as [GameDoc] whenever the room document changes.
  Stream<GameDoc> watchRoom(String code) {
    return _db
        .collection('games')
        .doc(code)
        .snapshots()
        .where((snap) => snap.exists)
        .map((snap) => GameDoc.fromSnapshot(snap));
  }

  /// Shares an invite link for the given [gameCode].
  Future<void> shareGameInvite(String gameCode) async {
    final uri = Uri.https(
      'link.atoll-attack.com',
      '/join',
      {'code': gameCode},
    ).toString();
    await Share.share(
      '🏝️ Join my Atoll Attack game: $uri',
      subject: 'Atoll Attack Invite',
    );
  }

  /// Listens for another player joining the room specified by [gameCode].
  /// Returns a subscription that auto-cancels once the second player arrives.
  Future<StreamSubscription<GameDoc>> listenForJoin(
    String gameCode,
    void Function(GameDoc) onPlayerJoined,
  ) async {
    late final StreamSubscription<GameDoc> sub;
    sub = watchRoom(gameCode).listen((gameDoc) {
      if (gameDoc.players.length > 1) {
        logger.i("Player has joined: ${gameDoc.players}");
        onPlayerJoined(gameDoc);
        sub.cancel();
      }
    });
    return sub;
  }
}
