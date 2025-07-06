// lib/services/webrtc_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

class WebRTCService {
  // Singleton
  static final WebRTCService _instance = WebRTCService._internal();
  static WebRTCService get instance => _instance;
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  StreamSubscription<QuerySnapshot>? _signalSub;
  Timer? _statsTimer;

  String? _currentGameCode;
  String? _playerId;
  String? _playerColor;
  bool _isConnected = false;

  // Latency tracking
  final List<int> _latencySamples = [];
  DateTime? _pingSentAt;

  // Incoming commands & stats streams
  final _commandController = StreamController<Map<String, dynamic>>.broadcast();
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();

  /// Callbacks
  void Function(bool connected)? onConnectionStateChanged;
  void Function(Map<String, dynamic> stats)? onStats;

  /// Public getters
  bool get isConnected => _isConnected;
  String? get playerColor => _playerColor;
  String? get playerId => _playerId;
  Stream<Map<String, dynamic>> get commandStream => _commandController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  /// Average latency in ms
  int get averageLatency {
    if (_latencySamples.isEmpty) return 0;
    final sum = _latencySamples.reduce((a, b) => a + b);
    return (sum / _latencySamples.length).round();
  }

  /// Full latency stats
  Map<String, int> getLatencyStats() {
    if (_latencySamples.isEmpty) {
      return {'samples': 0, 'min': 0, 'max': 0, 'average': 0};
    }
    final min = _latencySamples.reduce((a, b) => a < b ? a : b);
    final max = _latencySamples.reduce((a, b) => a > b ? a : b);
    return {
      'samples': _latencySamples.length,
      'min': min,
      'max': max,
      'average': averageLatency,
    };
  }

  /// Send a test command over data channel
  void sendTestCommand() {
    sendCommand('test', {'message': 'Hello from ${_playerId ?? 'unknown'}'});
    _logger.i('🧪 Test command sent');
  }

  /// Initialize and connect
  Future<void> initialize(String gameCode, {String? authEmail}) async {
    _currentGameCode = gameCode;
    _playerId = authEmail ?? FirebaseAuth.instance.currentUser?.email;
    _logger.i('🚀 Initializing WebRTC for $gameCode as $_playerId');

    await _determinePlayerRole();
    await _createPeerConnection();
    await _setupDataChannel();
    _listenForSignaling();

    // Periodically gather stats
    _statsTimer = Timer.periodic(Duration(seconds: 5), (_) => _gatherStats());

    if (_playerColor == 'blue') {
      await _createOffer();
    }
    _isConnected = true;
    onConnectionStateChanged?.call(true);
  }

  /// Dispose everything
  Future<void> dispose() async {
    _statsTimer?.cancel();
    await _signalSub?.cancel();
    await _dataChannel?.close();
    await _peerConnection?.close();
    _isConnected = false;
    onConnectionStateChanged?.call(false);
  }

  /// Send ping for latency measurement
  void sendPing() {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    _pingSentAt = DateTime.now();
    _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
      'type': 'ping',
      'ts': _pingSentAt!.millisecondsSinceEpoch,
    })));
    _logger.i('🏓 Ping sent');
  }

  /// Send a generic command
  void sendCommand(String type, Map<String, dynamic> payload) {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      _logger.w('Cannot send, DataChannel not open: ${_dataChannel?.state}');
      return;
    }
    final msg = <String, dynamic>{
      'type': type,
      'player': _playerId,
      'payload': payload,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _dataChannel!.send(RTCDataChannelMessage(jsonEncode(msg)));
  }

  //////////////////////////////////////////////////////////////////////////////////
  // Internal helpers

  Future<void> _determinePlayerRole() async {
    final doc = _firestore.collection('games').doc(_currentGameCode);
    final snap = await doc.get();
    if (!snap.exists) throw Exception('Game not found');
    final raw = snap.data()!;
    final players = List<String>.from(raw['players'] ?? []);
    if (players.isEmpty ||
        (players.length == 1 && players.contains(_playerId))) {
      _playerColor = 'blue';
      await doc.update({
        'players': FieldValue.arrayUnion([_playerId])
      });
      _logger.i('🟦 Assigned as initiator');
    } else {
      _playerColor = 'red';
      players.add(_playerId!);
      await doc.update({'players': players});
      _logger.i('🟥 Assigned as joiner');
    }
  }

  Future<void> _createPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onIceGatheringState = (state) => _logger.d('ICE Gathering: $state');
    _peerConnection!.onIceConnectionState = (state) => _logger.d('ICE Connection: $state');
    _peerConnection!.onSignalingState = (state) => _logger.d('Signaling: $state');
    _peerConnection!.onConnectionState = (state) {
      final connected = state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _logger.i('Connection state: $state, connected? $connected');
      _isConnected = connected;
      onConnectionStateChanged?.call(connected);
    };
    _peerConnection!.onDataChannel = (channel) {
      _logger.i('Remote DataChannel: ${channel.label}');
      _dataChannel = channel;
      _setupIncoming();
    };
    _peerConnection!.onIceCandidate = (candidate) {
      _logger.t('ICE Candidate: ${candidate.toMap()}');
              if (candidate.candidate != null) {
                _sendSignal({'candidate': candidate.toMap()});
              }
            };
  }

  Future<void> _setupDataChannel() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'game',
      RTCDataChannelInit()..ordered = true,
    );
    _logger.i('Local DataChannel: game');
    _setupIncoming();
  }

  void _setupIncoming() {
    _dataChannel!.onDataChannelState = (state) => _logger.i('DC State: $state');
    _dataChannel!.onMessage = (msg) {
      final obj = jsonDecode(msg.text) as Map<String, dynamic>;
      _logger.d('Received message: $obj');
      switch (obj['type']) {
        case 'ping':
          _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
            'type': 'pong',
            'ts': obj['ts'],
              })));
              break;
            case 'pong':
              if (_pingSentAt != null) {
                final sentAt = DateTime.fromMillisecondsSinceEpoch(obj['ts']);
                final latency =
                    DateTime.now().difference(sentAt).inMilliseconds;
                _latencySamples.add(latency);
                _logger.i('🏓 Latency: ${latency}ms');
              }
              break;
            default:
              _commandController.add(obj);
          }
        };
  }

  void _listenForSignaling() {
    _signalSub = _firestore
        .collection('games')
        .doc(_currentGameCode)
        .collection('signals')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      _logger.d('Signaling updates: ${snapshot.docChanges.length}');
      for (final change in snapshot.docChanges) {
        final data = change.doc.data()!;
        if (data['sender'] == _playerId) continue;

        if (data.containsKey('sdp')) {
          _logger.i('SDP ${data['type']} received');
          final desc = RTCSessionDescription(data['sdp'], data['type']);
          _peerConnection!.setRemoteDescription(desc);
          if (_playerColor == 'red') {
            _createAnswer();
          }
        }

        if (data.containsKey('candidate')) {
          _logger.i('ICE candidate received');
          final c = data['candidate'] as Map<String, dynamic>;
          _peerConnection!.addCandidate(RTCIceCandidate(
            c['candidate'],
            c['sdpMid'],
            c['sdpMLineIndex'],
          ));
        }
      }
    });
  }

  Future<void> _createOffer() async {
    _logger.i('Creating offer');
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    await _sendSignal({'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _createAnswer() async {
    _logger.i('Creating answer');
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _sendSignal({'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _sendSignal(Map<String, dynamic> message) async {
    _logger.t('Sending signal: $message');
    await _firestore
        .collection('games')
        .doc(_currentGameCode)
        .collection('signals')
        .add({
      ...message,
      'sender': _playerId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _gatherStats() async {
    if (_peerConnection == null) return;
    final reports = await _peerConnection!.getStats();
    final stats = <String, dynamic>{};
    for (final report in reports) {
      stats[report.id] = report.values;
    }
    onStats?.call(stats);
    _statsController.add(stats);
    _logger.t('Stats: ${jsonEncode(stats)}');
  }
}
