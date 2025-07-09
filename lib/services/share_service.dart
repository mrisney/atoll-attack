// lib/services/share_service.dart
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import '../utils/app_logger.dart';
import 'webrtc_game_service.dart';

/// Service for sharing game invites and managing WebRTC room codes
/// 
/// Integrates with WebRTCGameService to provide:
/// - Room code generation and sharing
/// - Deep link creation for game invites
/// - Room status monitoring
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  final WebRTCGameService _gameService = WebRTCGameService.instance;

  /// Creates a new WebRTC game room and returns the room code
  Future<String?> createGameRoom() async {
    try {
      await _gameService.initialize();
      final roomCode = await _gameService.createRoom();
      
      if (roomCode != null) {
        AppLogger.multiplayer('Game room created: $roomCode');
        return roomCode;
      } else {
        AppLogger.error('Failed to create game room');
        return null;
      }
    } catch (e) {
      AppLogger.error('Error creating game room', e);
      return null;
    }
  }

  /// Joins an existing WebRTC game room
  Future<bool> joinGameRoom(String roomCode) async {
    try {
      await _gameService.initialize();
      final success = await _gameService.joinRoom(roomCode);
      
      if (success) {
        AppLogger.multiplayer('Successfully joined room: $roomCode');
        return true;
      } else {
        AppLogger.error('Failed to join room: $roomCode');
        return false;
      }
    } catch (e) {
      AppLogger.error('Error joining game room', e);
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

Room Code: $roomCode (just 2 digits!)

Tap to join: $deepLinkUrl

Or open the app and enter: $roomCode
''';

      await Share.share(
        shareText,
        subject: 'Atoll Attack - Battle Invitation',
      );

      AppLogger.info('Game invite shared for room: $roomCode');
    } catch (e) {
      AppLogger.error('Error sharing game invite', e);
    }
  }

  /// Shares a simple room code (for quick sharing)
  Future<void> shareRoomCode(String roomCode) async {
    try {
      await Share.share(
        '🏝️ Join my Atoll Attack game! Code: $roomCode (just 2 digits)',
        subject: 'Atoll Attack Room Code',
      );
      AppLogger.info('Room code shared: $roomCode');
    } catch (e) {
      AppLogger.error('Error sharing room code', e);
    }
  }

  /// Monitors a room for player joins and status changes (simplified)
  Stream<Map<String, dynamic>> watchRoom(String roomCode) {
    // Return a simple stream that emits room status
    return Stream.periodic(const Duration(seconds: 2), (count) {
      return {
        'code': roomCode,
        'state': 'active',
        'players': ['host', 'guest'],
        'maxPlayers': 2,
      };
    }).take(5); // Emit 5 updates then complete
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
        AppLogger.game("Player joined room $roomCode: ${players.length} players");
        onPlayerJoined(roomData);
        sub.cancel(); // Auto-cancel after first join
      }
    });
    
    return sub;
  }

  /// Gets room information without subscribing (simplified)
  Future<Map<String, dynamic>?> getRoomInfo(String roomCode) async {
    try {
      // Return mock room info for now
      return {
        'code': roomCode,
        'state': 'waiting',
        'players': [],
        'maxPlayers': 2,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      AppLogger.error('Error getting room info', e);
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
      AppLogger.error('Error checking room availability', e);
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
    await _gameService.leaveRoom();
  }
}
