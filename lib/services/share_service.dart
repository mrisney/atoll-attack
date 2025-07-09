// lib/services/share_service.dart
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:logger/logger.dart';
import 'webrtc_game_service.dart';

final logger = Logger();

/// Service for sharing game invites and managing WebRTC room codes
/// 
/// Integrates with WebRTCGameService to provide:
/// - Room code generation and sharing
/// - Deep link creation for game invites
/// - Room status monitoring
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final WebRTCGameService _gameService = WebRTCGameService.instance;

  /// Creates a new WebRTC game room and returns the room code
  Future<String?> createGameRoom() async {
    try {
      await _gameService.initialize();
      final roomCode = await _gameService.createRoom();
      
      if (roomCode != null) {
        logger.i('🏠 Game room created: $roomCode');
        return roomCode;
      } else {
        logger.e('❌ Failed to create game room');
        return null;
      }
    } catch (e) {
      logger.e('❌ Error creating game room: $e');
      return null;
    }
  }

  /// Joins an existing WebRTC game room
  Future<bool> joinGameRoom(String roomCode) async {
    try {
      await _gameService.initialize();
      final success = await _gameService.joinRoom(roomCode);
      
      if (success) {
        logger.i('🚪 Successfully joined room: $roomCode');
        return true;
      } else {
        logger.e('❌ Failed to join room: $roomCode');
        return false;
      }
    } catch (e) {
      logger.e('❌ Error joining game room: $e');
      return false;
    }
  }

  /// Shares a game invite with the room code
  Future<void> shareGameInvite(String roomCode) async {
    try {
      // Create deep link URL
      final deepLinkUrl = Uri.https(
        'link.atoll-attack.com',
        '/join',
        {'code': roomCode},
      ).toString();

      // Create custom app scheme URL as fallback
      final appSchemeUrl = 'atoll://join?code=$roomCode';

      // Share message with both URLs
      final shareText = '''
🏝️ Join my Atoll Attack battle!

Room Code: $roomCode

Tap to join: $deepLinkUrl

Or open the app and enter code: $roomCode
''';

      await Share.share(
        shareText,
        subject: 'Atoll Attack - Battle Invitation',
      );

      logger.i('📤 Game invite shared for room: $roomCode');
    } catch (e) {
      logger.e('❌ Error sharing game invite: $e');
    }
  }

  /// Shares a simple room code (for quick sharing)
  Future<void> shareRoomCode(String roomCode) async {
    try {
      await Share.share(
        '🏝️ Join my Atoll Attack game with code: $roomCode',
        subject: 'Atoll Attack Room Code',
      );
      logger.i('📤 Room code shared: $roomCode');
    } catch (e) {
      logger.e('❌ Error sharing room code: $e');
    }
  }

  /// Monitors a room for player joins and status changes
  Stream<Map<String, dynamic>> watchRoom(String roomCode) {
    return _db
        .collection('game_rooms')
        .doc(roomCode)
        .snapshots()
        .where((snap) => snap.exists)
        .map((snap) => snap.data()!);
  }

  /// Listens for another player joining the specified room
  /// Returns a subscription that auto-cancels once a player joins
  Future<StreamSubscription<Map<String, dynamic>>> listenForPlayerJoin(
    String roomCode,
    void Function(Map<String, dynamic>) onPlayerJoined,
  ) async {
    late final StreamSubscription<Map<String, dynamic>> sub;
    
    sub = watchRoom(roomCode).listen((roomData) {
      final players = List<String>.from(roomData['players'] ?? []);
      final status = roomData['status'] as String;
      
      // Check if we have more than one player and status changed
      if (players.length > 1 && (status == 'connecting' || status == 'connected')) {
        logger.i("🎮 Player joined room $roomCode: ${players.length} players");
        onPlayerJoined(roomData);
        sub.cancel(); // Auto-cancel after first join
      }
    });
    
    return sub;
  }

  /// Gets room information without subscribing
  Future<Map<String, dynamic>?> getRoomInfo(String roomCode) async {
    try {
      final doc = await _db.collection('game_rooms').doc(roomCode).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      logger.e('❌ Error getting room info: $e');
      return null;
    }
  }

  /// Checks if a room code is valid and available
  Future<bool> isRoomAvailable(String roomCode) async {
    try {
      final roomInfo = await getRoomInfo(roomCode);
      if (roomInfo == null) return false;
      
      final status = roomInfo['status'] as String;
      final players = List<String>.from(roomInfo['players'] ?? []);
      
      // Room is available if it's waiting and has space
      return status == 'waiting' && players.length < (roomInfo['maxPlayers'] ?? 2);
    } catch (e) {
      logger.e('❌ Error checking room availability: $e');
      return false;
    }
  }

  /// Generates a shareable game URL for web/social sharing
  String generateGameUrl(String roomCode) {
    return Uri.https(
      'link.atoll-attack.com',
      '/join',
      {'code': roomCode},
    ).toString();
  }

  /// Generates app scheme URL for direct app opening
  String generateAppSchemeUrl(String roomCode) {
    return 'atoll://join?code=$roomCode';
  }

  /// Cleanup method to disconnect from current room
  Future<void> disconnect() async {
    await _gameService.disconnect();
  }
}
