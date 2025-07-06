// lib/services/webrtc_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

final logger = Logger();

class WebRTCService {
  static final WebRTCService instance = WebRTCService._();
  WebRTCService._();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentGameCode;
  String? _playerId;
  String? _playerColor;
  bool _isConnected = false;
  bool _isInitiator = false;

  // Command handling
  int _commandCounter = 0;
  StreamController<Map<String, dynamic>>? _commandStreamController;
  Stream<Map<String, dynamic>>? commandStream;

  // Latency tracking
  final Map<String, int> _sentTimestamps = {};
  final List<int> _latencyHistory = [];
  int _averageLatency = 0;
  Timer? _latencyTimer;

  // Connection state callback
  Function(bool)? onConnectionStateChanged;

  /// Initialize the WebRTC service with a game code
  Future<void> initialize(String gameCode) async {
    try {
      _currentGameCode = gameCode;
      _playerId = FirebaseAuth.instance.currentUser?.uid;

      logger.i('🎮 Initializing WebRTC for game: $gameCode');
      logger.i('👤 Player ID: $_playerId');

      // Set up command stream
      _commandStreamController =
          StreamController<Map<String, dynamic>>.broadcast();
      commandStream = _commandStreamController!.stream;

      // Check if we're first or second player
      await _determinePlayerRole();

      // Initialize WebRTC
      await _initializeWebRTC();

      // Start connection process
      if (_isInitiator) {
        await _createOffer();
      } else {
        await _waitForOffer();
      }

      logger.i('✅ WebRTC Service initialized successfully');
    } catch (e) {
      logger.e('❌ Failed to initialize WebRTC: $e');
      rethrow;
    }
  }

  /// Determine if we're the initiator (first player) or joiner (second player)
  Future<void> _determinePlayerRole() async {
    try {
      final gameRef = _firestore.collection('games').doc(_currentGameCode);
      final snapshot = await gameRef.get();

      if (!snapshot.exists) {
        throw Exception('Game not found');
      }

      final data = snapshot.data()!;
      final players = List<String>.from(data['players'] ?? []);

      if (players.isEmpty || players.first == _playerId) {
        _isInitiator = true;
        _playerColor = 'blue';
        logger.i('🔵 Acting as INITIATOR (blue player)');
      } else {
        _isInitiator = false;
        _playerColor = 'red';
        logger.i('🔴 Acting as JOINER (red player)');
      }
    } catch (e) {
      logger.e('❌ Error determining player role: $e');
      rethrow;
    }
  }

  /// Initialize WebRTC peer connection
  Future<void> _initializeWebRTC() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    // Set up ICE candidate handler
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        _sendSignalingMessage('ice-candidate', {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
        });
      }
    };

    // Set up connection state handler
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      logger.i('📡 Connection state: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _onConnected();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _onDisconnected();
      }
    };

    // Set up data channel
    if (_isInitiator) {
      await _createDataChannel();
    } else {
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        _dataChannel = channel;
        _setupDataChannel();
      };
    }
  }

  /// Create data channel for game commands
  Future<void> _createDataChannel() async {
    final channelConfig = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 3;

    _dataChannel = await _peerConnection!
        .createDataChannel('game-commands', channelConfig);
    _setupDataChannel();
  }

  /// Set up data channel event handlers
  void _setupDataChannel() {
    _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
      logger.i('📊 Data channel state: $state');

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _isConnected = true;
        onConnectionStateChanged?.call(true);
        _startLatencyMonitoring();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _isConnected = false;
        onConnectionStateChanged?.call(false);
        _stopLatencyMonitoring();
      }
    };

    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        logger.w('Received binary message, ignoring');
        return;
      }

      try {
        final data = jsonDecode(message.text);
        _handleIncomingCommand(data);
      } catch (e) {
        logger.e('Error parsing message: $e');
      }
    };
  }

  /// Create WebRTC offer (initiator)
  Future<void> _createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _sendSignalingMessage('offer', {
      'sdp': offer.sdp,
      'type': offer.type,
    });

    // Listen for answer
    _listenForSignaling();
  }

  /// Wait for WebRTC offer (joiner)
  Future<void> _waitForOffer() async {
    _listenForSignaling();
  }

  /// Listen for signaling messages via Firestore
  void _listenForSignaling() {
    final signalingRef = _firestore
        .collection('games')
        .doc(_currentGameCode)
        .collection('signaling')
        .where('to', isEqualTo: _playerId)
        .where('processed', isEqualTo: false);

    signalingRef.snapshots().listen((snapshot) async {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        await _handleSignalingMessage(data);

        // Mark as processed
        await doc.reference.update({'processed': true});
      }
    });
  }

  /// Handle incoming signaling message
  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
    final type = message['type'];
    final payload = message['payload'];

    logger.i('📨 Received signaling: $type');

    switch (type) {
      case 'offer':
        final offer = RTCSessionDescription(payload['sdp'], payload['type']);
        await _peerConnection!.setRemoteDescription(offer);

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);

        await _sendSignalingMessage('answer', {
          'sdp': answer.sdp,
          'type': answer.type,
        });
        break;

      case 'answer':
        final answer = RTCSessionDescription(payload['sdp'], payload['type']);
        await _peerConnection!.setRemoteDescription(answer);
        break;

      case 'ice-candidate':
        final candidate = RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
        break;
    }
  }

  /// Send signaling message via Firestore
  Future<void> _sendSignalingMessage(
      String type, Map<String, dynamic> payload) async {
    final otherPlayerId = await _getOtherPlayerId();
    if (otherPlayerId == null) {
      logger.w('No other player to send signaling to');
      return;
    }

    await _firestore
        .collection('games')
        .doc(_currentGameCode)
        .collection('signaling')
        .add({
      'from': _playerId,
      'to': otherPlayerId,
      'type': type,
      'payload': payload,
      'timestamp': FieldValue.serverTimestamp(),
      'processed': false,
    });
  }

  /// Get the other player's ID
  Future<String?> _getOtherPlayerId() async {
    final gameRef = _firestore.collection('games').doc(_currentGameCode);
    final snapshot = await gameRef.get();

    if (!snapshot.exists) return null;

    final players = List<String>.from(snapshot.data()!['players'] ?? []);
    return players.firstWhere((id) => id != _playerId, orElse: () => '');
  }

  /// Handle connection established
  void _onConnected() {
    logger.i('✅ WebRTC connection established!');
    _isConnected = true;

    // Send initial join command
    sendCommand('join', {
      'playerId': _playerId,
      'color': _playerColor,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle connection lost
  void _onDisconnected() {
    logger.w('⚠️ WebRTC connection lost');
    _isConnected = false;
    _stopLatencyMonitoring();
  }

  /// Send a command through the data channel
  Future<void> sendCommand(String type, Map<String, dynamic> data,
      {bool skipLogging = false}) async {
    if (!_isConnected ||
        _dataChannel == null ||
        _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      logger.e('❌ Cannot send command - not connected');
      return;
    }

    try {
      _commandCounter++;

      final command = {
        'id': '${_playerId}_${_commandCounter}',
        'playerId': _playerId,
        'playerColor': _playerColor,
        'type': type,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final message = jsonEncode(command);
      await _dataChannel!.send(RTCDataChannelMessage(message));

      if (!skipLogging) {
        logger.i('📤 Sent command: $type');
      }
    } catch (e) {
      logger.e('❌ Failed to send command: $e');
    }
  }

  /// Handle incoming command
  void _handleIncomingCommand(Map<String, dynamic> command) {
    final isOwnCommand = command['playerId'] == _playerId;

    // Handle ping/pong for latency measurement
    if (command['type'] == 'ping' && !isOwnCommand) {
      _handlePing(command);
      return;
    } else if (command['type'] == 'pong' && !isOwnCommand) {
      _handlePong(command);
      return;
    }

    // Forward to command stream
    _commandStreamController?.add(command);

    // Log command
    if (!isOwnCommand ||
        (command['type'] != 'ping' && command['type'] != 'pong')) {
      final emoji = isOwnCommand ? '📤' : '📥';
      final playerColor = command['playerColor'] ?? 'unknown';

      logger.i('$emoji Command ${isOwnCommand ? "SENT" : "RECEIVED"} '
          'from $playerColor player:');
      logger.i('  Type: ${command['type']}');
      logger.i('  Data: ${command['data']}');

      if (!isOwnCommand) {
        logger.w('🎯 OPPONENT ACTION: ${command['type']} - ${command['data']}');
      }
    }
  }

  /// Start latency monitoring
  void _startLatencyMonitoring() {
    _latencyTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isConnected) {
        _sendPing();
      }
    });
  }

  /// Stop latency monitoring
  void _stopLatencyMonitoring() {
    _latencyTimer?.cancel();
    _latencyTimer = null;
  }

  /// Send ping for latency measurement
  Future<void> _sendPing() async {
    final pingId = 'ping_${DateTime.now().millisecondsSinceEpoch}';
    _sentTimestamps[pingId] = DateTime.now().millisecondsSinceEpoch;

    await sendCommand(
        'ping',
        {
          'pingId': pingId,
          'clientTime': DateTime.now().millisecondsSinceEpoch,
        },
        skipLogging: true);
  }

  /// Handle incoming ping
  void _handlePing(Map<String, dynamic> command) {
    final pingData = command['data'] as Map;
    sendCommand(
        'pong',
        {
          'pingId': pingData['pingId'],
          'originalTime': pingData['clientTime'],
          'responseTime': DateTime.now().millisecondsSinceEpoch,
        },
        skipLogging: true);
  }

  /// Handle incoming pong
  void _handlePong(Map<String, dynamic> command) {
    final pongData = command['data'] as Map;
    final pingId = pongData['pingId'];

    if (_sentTimestamps.containsKey(pingId)) {
      final sentTime = _sentTimestamps[pingId]!;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final roundTripTime = currentTime - sentTime;
      final latency = roundTripTime ~/ 2;

      _latencyHistory.add(latency);
      if (_latencyHistory.length > 10) {
        _latencyHistory.removeAt(0);
      }

      _averageLatency =
          _latencyHistory.reduce((a, b) => a + b) ~/ _latencyHistory.length;

      logger.i('📡 WebRTC Latency: ${latency}ms (avg: ${_averageLatency}ms)');

      _sentTimestamps.remove(pingId);
    }
  }

  /// Send a test command
  Future<void> sendTestCommand() async {
    await sendCommand('test', {
      'message': 'Hello from $_playerColor player via WebRTC!',
      'counter': _commandCounter,
      'time': DateTime.now().toIso8601String(),
    });
  }

  /// Clean up resources
  Future<void> dispose() async {
    logger.i('🔌 Disconnecting WebRTC service...');

    _stopLatencyMonitoring();

    if (_isConnected) {
      await sendCommand('leave', {
        'playerId': _playerId,
        'color': _playerColor,
      });
    }

    await _dataChannel?.close();
    await _peerConnection?.close();
    await _commandStreamController?.close();

    _isConnected = false;

    logger.i('👋 WebRTC service disposed');
  }

  // Getters
  bool get isConnected => _isConnected;
  String? get playerColor => _playerColor;
  String? get playerId => _playerId;
  int get averageLatency => _averageLatency;
  List<int> get latencyHistory => List.unmodifiable(_latencyHistory);
}
