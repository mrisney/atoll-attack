// lib/services/webrtc_game_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

/// WebRTC-based real-time communication service for Atoll Attack multiplayer
/// 
/// Features:
/// - Peer-to-peer WebRTC data channels for low-latency communication
/// - Firebase Firestore for signaling (room creation, offers, answers, ICE candidates)
/// - Game command synchronization with latency measurement
/// - Automatic reconnection and error handling
/// - Support for 2-4 players per room
class WebRTCGameService {
  static final WebRTCGameService _instance = WebRTCGameService._internal();
  static WebRTCGameService get instance => _instance;
  WebRTCGameService._internal();

  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // WebRTC Connection
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  
  // Game State
  String? _roomCode;
  String? _playerId;
  bool _isHost = false;
  String _connectionState = 'Disconnected';
  
  // Listeners
  StreamSubscription? _roomSubscription;
  StreamSubscription? _iceCandidatesSubscription;
  
  // Callbacks
  Function(Map<String, dynamic>)? onGameCommandReceived;
  Function(String)? onConnectionStateChanged;
  Function(String)? onPlayerJoined;
  Function(String)? onPlayerLeft;
  Function(double)? onLatencyMeasured;
  
  // Latency tracking
  final Map<String, int> _sentCommandTimestamps = {};
  final List<double> _latencyMeasurements = [];
  double _averageLatency = 0.0;
  
  // Getters
  String? get roomCode => _roomCode;
  String? get playerId => _playerId;
  bool get isHost => _isHost;
  String get connectionState => _connectionState;
  double get averageLatency => _averageLatency;
  bool get isConnected => _connectionState == 'connected' && _dataChannel != null;

  /// Initialize the service with a unique player ID
  Future<void> initialize() async {
    _playerId = _generatePlayerId();
    _logger.i('🎮 WebRTC Game Service initialized - Player: $_playerId');
  }

  /// Create a new game room and become the host
  Future<String?> createRoom() async {
    try {
      _isHost = true;
      _roomCode = _generateRoomCode();
      
      await _createPeerConnection();
      await _createDataChannel();
      
      // Create WebRTC offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Store room in Firestore
      await _firestore.collection('game_rooms').doc(_roomCode!).set({
        'offer': offer.toMap(),
        'host': _playerId,
        'created': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'players': [_playerId],
        'maxPlayers': 2, // Can be expanded to 4 later
      });
      
      _startRoomListener();
      _logger.i('🏠 Room created: $_roomCode');
      
      return _roomCode;
    } catch (e) {
      _logger.e('❌ Error creating room: $e');
      return null;
    }
  }

  /// Join an existing game room
  Future<bool> joinRoom(String roomCode) async {
    try {
      _isHost = false;
      _roomCode = roomCode;
      
      // Check if room exists
      final roomDoc = await _firestore.collection('game_rooms').doc(roomCode).get();
      if (!roomDoc.exists) {
        _logger.e('❌ Room $roomCode not found');
        return false;
      }
      
      final roomData = roomDoc.data()!;
      if (roomData['status'] != 'waiting') {
        _logger.e('❌ Room $roomCode is not available');
        return false;
      }
      
      await _createPeerConnection();
      
      // Set remote offer
      final offerData = roomData['offer'];
      final offer = RTCSessionDescription(offerData['sdp'], offerData['type']);
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Update room with answer
      await _firestore.collection('game_rooms').doc(roomCode).update({
        'answer': answer.toMap(),
        'guest': _playerId,
        'status': 'connecting',
        'players': FieldValue.arrayUnion([_playerId]),
      });
      
      _startRoomListener();
      _logger.i('🚪 Joined room: $roomCode');
      
      return true;
    } catch (e) {
      _logger.e('❌ Error joining room: $e');
      return false;
    }
  }

  /// Send a game command to the peer (legacy method)
  Future<void> sendLegacyGameCommand(String commandType, Map<String, dynamic> data) async {
    if (!isConnected) {
      _logger.w('⚠️ Cannot send command - not connected');
      return;
    }
    
    final commandId = '${_playerId}_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final command = {
      'type': 'game_command',
      'commandType': commandType,
      'data': data,
      'id': commandId,
      'timestamp': timestamp,
      'from': _playerId,
    };
    
    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(command)));
      _sentCommandTimestamps[commandId] = timestamp;
      _logger.d('📤 Game command sent: $commandType');
    } catch (e) {
      _logger.e('❌ Error sending game command: $e');
    }
  }

  /// Send a full game command (new method for command system)
  Future<void> sendGameCommand(Map<String, dynamic> commandJson) async {
    if (!isConnected) {
      _logger.w('⚠️ Cannot send command - not connected');
      return;
    }
    
    final message = {
      'type': 'game_command_v2',
      'command': commandJson,
      'from': _playerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message)));
      _logger.d('📤 Game command sent: ${commandJson['commandType']}');
    } catch (e) {
      _logger.e('❌ Error sending game command: $e');
    }
  }

  /// Send a ping to measure latency
  Future<void> sendPing() async {
    if (!isConnected) return;
    
    final pingId = 'ping_${_playerId}_${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final ping = {
      'type': 'ping',
      'id': pingId,
      'timestamp': timestamp,
      'from': _playerId,
    };
    
    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(ping)));
      _sentCommandTimestamps[pingId] = timestamp;
    } catch (e) {
      _logger.e('❌ Error sending ping: $e');
    }
  }

  /// Leave the current room and disconnect
  Future<void> leaveRoom() async {
    if (_roomCode == null) {
      _logger.w('⚠️ No room to leave');
      return;
    }

    _logger.i('🚪 Leaving room: $_roomCode');
    
    try {
      // Update room status in Firestore
      if (_roomCode != null) {
        await _firestore.collection('game_rooms').doc(_roomCode!).update({
          'players': FieldValue.arrayRemove([_playerId]),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.w('⚠️ Error updating room on leave: $e');
    }

    // Disconnect WebRTC
    await disconnect();
    
    _logger.i('🚪 Successfully left room');
  }
  Future<void> disconnect() async {
    _roomSubscription?.cancel();
    _iceCandidatesSubscription?.cancel();
    
    _dataChannel?.close();
    _peerConnection?.close();
    
    if (_roomCode != null) {
      try {
        await _firestore.collection('game_rooms').doc(_roomCode!).update({
          'status': 'disconnected',
          'disconnected_at': FieldValue.serverTimestamp(),
          'players': FieldValue.arrayRemove([_playerId]),
        });
      } catch (e) {
        _logger.w('⚠️ Could not update room status: $e');
      }
    }
    
    _dataChannel = null;
    _peerConnection = null;
    _roomCode = null;
    _isHost = false;
    _updateConnectionState('Disconnected');
    
    _logger.i('🔌 Disconnected from room');
  }

  /// Clean up resources
  void dispose() {
    disconnect();
  }

  // Private Methods

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);
    
    _peerConnection!.onConnectionState = (state) {
      _updateConnectionState(state.name);
    };

    _peerConnection!.onIceConnectionState = (state) {
      _logger.d('🧊 ICE state: ${state.name}');
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (_roomCode != null && candidate.candidate != null) {
        _storeIceCandidate(candidate);
      }
    };

    _peerConnection!.onDataChannel = (channel) {
      _logger.i('📨 Data channel received from peer');
      _setupDataChannel(channel);
    };
  }

  Future<void> _createDataChannel() async {
    final dataChannelInit = RTCDataChannelInit();
    _dataChannel = await _peerConnection!.createDataChannel('game_commands', dataChannelInit);
    _setupDataChannel(_dataChannel!);
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    
    _dataChannel!.onMessage = (message) {
      final receivedTime = DateTime.now().millisecondsSinceEpoch;
      _handleReceivedMessage(message.text, receivedTime);
    };

    _dataChannel!.onDataChannelState = (state) {
      _logger.d('📡 Data channel state: ${state.name}');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _updateConnectionState('connected');
      }
    };
  }

  void _handleReceivedMessage(String messageText, int receivedTime) {
    try {
      final message = jsonDecode(messageText);
      final type = message['type'];
      final messageId = message['id'];
      
      switch (type) {
        case 'game_command':
          final commandType = message['commandType'];
          final data = message['data'];
          final timestamp = message['timestamp'] as int;
          
          onGameCommandReceived?.call({
            'commandType': commandType,
            'data': data,
            'from': message['from'],
            'timestamp': timestamp,
          });
          
          // Send acknowledgment
          _sendAck(messageId, timestamp);
          break;

        case 'game_command_v2':
          // New command format - pass the full command JSON
          final command = message['command'] as Map<String, dynamic>;
          final timestamp = message['timestamp'] as int;
          
          print('📨 DEBUG: Received game_command_v2: $command');
          print('📨 DEBUG: Command timestamp: $timestamp');
          print('📨 DEBUG: onGameCommandReceived callback is ${onGameCommandReceived != null ? 'set' : 'null'}');
          
          onGameCommandReceived?.call(command);
          break;
          
        case 'ack':
          final originalTimestamp = message['originalTimestamp'] as int;
          if (_sentCommandTimestamps.containsKey(messageId)) {
            final latency = (receivedTime - originalTimestamp) / 2.0;
            _recordLatency(latency);
            _sentCommandTimestamps.remove(messageId);
          }
          break;
          
        case 'ping':
          _sendPong(messageId, message['timestamp']);
          break;
          
        case 'pong':
          final originalTimestamp = message['originalTimestamp'] as int;
          if (_sentCommandTimestamps.containsKey(messageId)) {
            final latency = receivedTime - originalTimestamp;
            _recordLatency(latency.toDouble());
            _sentCommandTimestamps.remove(messageId);
          }
          break;
      }
    } catch (e) {
      _logger.e('❌ Error handling received message: $e');
    }
  }

  void _sendAck(String messageId, int originalTimestamp) {
    if (_dataChannel == null) return;
    
    final ack = {
      'type': 'ack',
      'id': messageId,
      'originalTimestamp': originalTimestamp,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(ack)));
    } catch (e) {
      _logger.e('❌ Error sending ack: $e');
    }
  }

  void _sendPong(String pingId, int originalTimestamp) {
    if (_dataChannel == null) return;
    
    final pong = {
      'type': 'pong',
      'id': pingId,
      'originalTimestamp': originalTimestamp,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    try {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(pong)));
    } catch (e) {
      _logger.e('❌ Error sending pong: $e');
    }
  }

  void _recordLatency(double latency) {
    _latencyMeasurements.add(latency);
    
    // Keep only last 10 measurements
    if (_latencyMeasurements.length > 10) {
      _latencyMeasurements.removeAt(0);
    }
    
    _averageLatency = _latencyMeasurements.reduce((a, b) => a + b) / _latencyMeasurements.length;
    onLatencyMeasured?.call(latency);
  }

  Future<void> _storeIceCandidate(RTCIceCandidate candidate) async {
    if (_roomCode == null) return;
    
    try {
      await _firestore.collection('game_rooms').doc(_roomCode!).collection('ice_candidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'from': _playerId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('❌ Error storing ICE candidate: $e');
    }
  }

  void _startRoomListener() {
    if (_roomCode == null) return;
    
    // Listen to room document changes
    _roomSubscription = _firestore.collection('game_rooms').doc(_roomCode!).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _handleRoomUpdate(snapshot.data()!);
      }
    });
    
    // Listen to ICE candidates
    _iceCandidatesSubscription = _firestore.collection('game_rooms').doc(_roomCode!)
        .collection('ice_candidates')
        .where('from', isNotEqualTo: _playerId)
        .snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleIceCandidate(change.doc.data()!);
        }
      }
    });
  }

  void _handleRoomUpdate(Map<String, dynamic> data) async {
    try {
      // If we're host and there's an answer, set it as remote description
      if (_isHost && data.containsKey('answer') && !data.containsKey('answer_processed')) {
        final answerData = data['answer'];
        final answer = RTCSessionDescription(answerData['sdp'], answerData['type']);
        await _peerConnection!.setRemoteDescription(answer);
        
        // Mark as processed
        await _firestore.collection('game_rooms').doc(_roomCode!).update({
          'answer_processed': true,
          'status': 'connected',
        });
        
        _logger.i('📝 Remote answer processed');
      }
      
      // Handle player changes
      if (data.containsKey('players')) {
        final players = List<String>.from(data['players']);
        // Notify about new players (simplified for 2-player games)
        if (players.length > 1 && players.length > (_isHost ? 1 : 0)) {
          final otherPlayer = players.firstWhere((p) => p != _playerId);
          onPlayerJoined?.call(otherPlayer);
        }
      }
    } catch (e) {
      _logger.e('❌ Error handling room update: $e');
    }
  }

  void _handleIceCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      _logger.e('❌ Error adding ICE candidate: $e');
    }
  }

  void _updateConnectionState(String state) {
    print('🔗 DEBUG: Connection state changing from ${_connectionState} to $state');
    _connectionState = state;
    print('🔗 DEBUG: isConnected now: $isConnected (state: $state, dataChannel: ${_dataChannel != null})');
    onConnectionStateChanged?.call(state);
    _logger.d('🔗 Connection state: $state');
  }

  String _generatePlayerId() {
    return 'player_${Random().nextInt(9999).toString().padLeft(4, '0')}';
  }

  String _generateRoomCode() {
    return Random().nextInt(99).toString().padLeft(2, '0');
  }
}
