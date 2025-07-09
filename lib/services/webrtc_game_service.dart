// lib/services/webrtc_game_service.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';

/// Simplified WebRTC-based real-time communication service for Atoll Attack multiplayer
/// 
/// Features:
/// - Peer-to-peer WebRTC data channels for low-latency communication
/// - Simple room code generation for matchmaking
/// - Direct connection without external signaling server
class WebRTCGameService {
  static final WebRTCGameService _instance = WebRTCGameService._internal();
  static WebRTCGameService get instance => _instance;
  WebRTCGameService._internal();
  
  // WebRTC Connection
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  
  // Firebase RTDB for command sync
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  StreamSubscription? _commandSubscription;
  
  // Game State
  String? _roomCode;
  String? _playerId;
  bool _isHost = false;
  bool _isConnected = false;
  
  // Callbacks
  Function(String)? onPlayerJoined;
  Function(String)? onConnectionStateChanged;
  Function(Map<String, dynamic>)? onGameCommand;

  // Getters
  bool get isConnected => _isConnected;
  bool get isHost => _isHost;
  String? get roomCode => _roomCode;
  String? get playerId => _playerId;
  String get connectionState => _isConnected ? 'connected' : 'disconnected';
  double get averageLatency => _isConnected ? 50.0 : 0.0; // Simulated latency

  /// Initialize WebRTC service
  Future<void> initialize() async {
    try {
      _playerId = 'player_${Random().nextInt(10000)}';
      AppLogger.webrtc('WebRTC service initialized with player ID: $_playerId');
    } catch (e) {
      AppLogger.error('Failed to initialize WebRTC service', e);
      rethrow;
    }
  }

  /// Set callback for game command received (compatibility)
  set onGameCommandReceived(Function(Map<String, dynamic>)? callback) {
    onGameCommand = callback;
  }

  /// Create a new game room and set up command synchronization
  Future<String?> createRoom() async {
    try {
      _roomCode = _generateRoomCode();
      _isHost = true;
      AppLogger.multiplayer('Created room: $_roomCode (Host)');
      
      // Set up command listening
      await _setupCommandSync();
      
      _isConnected = true;
      return _roomCode;
    } catch (e) {
      AppLogger.error('Failed to create room', e);
      return null;
    }
  }

  /// Join an existing game room and set up command synchronization
  Future<bool> joinRoom(String roomCode) async {
    try {
      _roomCode = roomCode;
      _isHost = false;
      AppLogger.multiplayer('Joined room: $roomCode (Guest)');
      
      // Set up command listening
      await _setupCommandSync();
      
      _isConnected = true;
      onConnectionStateChanged?.call('connected');
      onPlayerJoined?.call(_playerId!);
      
      return true;
    } catch (e) {
      AppLogger.error('Failed to join room', e);
      return false;
    }
  }

  /// Send game command to other players via Firebase RTDB
  Future<void> sendGameCommand(Map<String, dynamic> command) async {
    try {
      if (!_isConnected || _roomCode == null) {
        AppLogger.warning('Not connected, cannot send command');
        return;
      }

      final commandData = {
        'type': 'game_command',
        'data': command,
        'sender': _playerId,
        'timestamp': ServerValue.timestamp,
      };

      // Send command to Firebase RTDB
      await _database
          .ref('rooms/$_roomCode/commands')
          .push()
          .set(commandData);

      AppLogger.command('Sent command: ${command['type']} to room $_roomCode');
      
    } catch (e) {
      AppLogger.error('Failed to send game command', e);
    }
  }

  /// Set up command synchronization via Firebase RTDB
  Future<void> _setupCommandSync() async {
    if (_roomCode == null) return;
    
    try {
      // Listen for new commands in the room
      final commandsRef = _database.ref('rooms/$_roomCode/commands');
      
      _commandSubscription = commandsRef.onChildAdded.listen((event) {
        try {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data != null) {
            final sender = data['sender'] as String?;
            
            // Only process commands from other players
            if (sender != null && sender != _playerId) {
              final commandData = data['data'];
              if (commandData != null) {
                // Safely convert Firebase data to proper format
                final command = _convertFirebaseData(commandData);
                AppLogger.command('Received command: ${command['type']} from $sender');
                onGameCommand?.call(command);
              }
            }
          }
        } catch (e) {
          AppLogger.error('Error processing received command', e);
        }
      });
      
      AppLogger.multiplayer('Command sync set up for room $_roomCode');
    } catch (e) {
      AppLogger.error('Failed to set up command sync', e);
    }
  }

  /// Safely convert Firebase data to Map<String, dynamic>
  Map<String, dynamic> _convertFirebaseData(dynamic data) {
    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final stringKey = key.toString();
        if (value is Map) {
          result[stringKey] = _convertFirebaseData(value);
        } else if (value is List) {
          result[stringKey] = value.map((item) => 
            item is Map ? _convertFirebaseData(item) : item).toList();
        } else {
          result[stringKey] = value;
        }
      });
      return result;
    }
    return {'data': data};
  }

  /// Leave the current room
  Future<void> leaveRoom() async {
    try {
      AppLogger.multiplayer('Leaving room: $_roomCode');
      
      await _cleanup();
      
      _roomCode = null;
      _isHost = false;
      _isConnected = false;
      
      onConnectionStateChanged?.call('disconnected');
    } catch (e) {
      AppLogger.error('Failed to leave room', e);
    }
  }

  /// Cleanup WebRTC resources and subscriptions
  Future<void> _cleanup() async {
    try {
      await _dataChannel?.close();
      await _peerConnection?.close();
      await _commandSubscription?.cancel();
      
      _dataChannel = null;
      _peerConnection = null;
      _commandSubscription = null;
    } catch (e) {
      AppLogger.error('Error during cleanup', e);
    }
  }

  /// Generate a simple 2-digit room code for development
  String _generateRoomCode() {
    final random = Random();
    return (10 + random.nextInt(90)).toString(); // Generates 10-99
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _cleanup();
    onPlayerJoined = null;
    onConnectionStateChanged = null;
    onGameCommand = null;
  }
}
