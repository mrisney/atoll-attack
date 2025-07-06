// lib/services/webrtc_service_v2.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class WebRTCServiceV2 {
  WebRTCServiceV2._();
  static final WebRTCServiceV2 instance = WebRTCServiceV2._();

  final _log = Logger();
  final List<int> _rttSamples = [];
  late String _gameCode;
  String? _deviceId;
  
  // WebRTC components
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  StreamSubscription<DatabaseEvent>? _signalSubscription;
  
  // Command stream controller (same interface as RTDB)
  final StreamController<Map<String, dynamic>> _cmdCtrl =
      StreamController.broadcast();

  bool _initialized = false;
  bool _isHost = false;
  DatabaseReference? _signalRef;

  /// Same interface as RTDB service
  bool get isConnected => _initialized && 
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  int? get lastRtt => _rttSamples.isEmpty ? null : _rttSamples.last;

  double get avgRtt => _rttSamples.isEmpty
      ? 0
      : _rttSamples.reduce((a, b) => a + b) / _rttSamples.length;

  Stream<Map<String, dynamic>> get commandStream => _cmdCtrl.stream;

  /// Get or create a unique device ID
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('webrtc_device_id');

    if (deviceId == null) {
      final uuid = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      deviceId = '${uuid.substring(0, 8)}-$timestamp';
      await prefs.setString('webrtc_device_id', deviceId);
      _log.i('🆆 Generated new WebRTC device ID: ${deviceId.substring(0, 12)}...');
    }

    _deviceId = deviceId;
    return deviceId;
  }

  /// Initialize WebRTC service
  Future<void> initialize(String gameCode) async {
    _gameCode = gameCode;
    
    await _getDeviceId();
    _log.i('🔧 Initializing WebRTC with device ID: ${_deviceId?.substring(0, 8)}...');

    try {
      // Use Firebase RTDB for signaling
      _signalRef = FirebaseDatabase.instance.ref('webrtc_signals/$_gameCode');
      
      // Determine if we're host or client
      await _determineRole();
      _log.i('🎯 Role determined: ${_isHost ? "HOST" : "CLIENT"}');
      
      // Create peer connection
      await _createPeerConnection();
      _log.i('🔗 Peer connection created');
      
      // Setup signaling
      _listenForSignaling();
      _log.i('📡 Signaling listener started');
      
      if (_isHost) {
        _log.i('📤 HOST creating offer...');
        await _createOffer();
      } else {
        _log.i('📱 CLIENT waiting for offer...');
      }

      _log.i('✅ WebRTC initialized for game $_gameCode as ${_isHost ? "HOST" : "CLIENT"}');
    } catch (e) {
      _log.e('❌ Failed to initialize WebRTC: $e');
      rethrow;
    }
  }

  /// Determine if we're host or client
  Future<void> _determineRole() async {
    // Add small delay to prevent race conditions
    await Future.delayed(Duration(milliseconds: 100));
    
    final snapshot = await _signalRef!.child('host').get();
    if (!snapshot.exists) {
      _isHost = true;
      await _signalRef!.child('host').set(_deviceId);
      _log.i('🏠 Acting as HOST');
    } else {
      final existingHost = snapshot.value as String?;
      if (existingHost == _deviceId) {
        _isHost = true;
        _log.i('🏠 Already registered as HOST');
      } else {
        _isHost = false;
        await _signalRef!.child('client').set(_deviceId);
        _log.i('📱 Acting as CLIENT');
      }
    }
  }

  /// Create peer connection
  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    _peerConnection = await createPeerConnection(config);

    _peerConnection!.onConnectionState = (state) {
      final connected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _log.i('🔌 WebRTC Connection State: $state (connected: $connected)');
      
      if (connected && !_initialized) {
        _initialized = true;
        _log.i('🎉 WebRTC connection established - data channel ready!');
        sendCommand('join', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _log.e('❌ WebRTC connection failed');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _log.w('⚠️ WebRTC connection disconnected');
        _initialized = false;
      }
    };

    _peerConnection!.onIceConnectionState = (state) {
      _log.i('🧊 ICE Connection State: $state');
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendSignal('ice', {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection!.onDataChannel = (channel) {
      _log.i('📡 Remote data channel received');
      _dataChannel = channel;
      _setupDataChannel();
    };

    // Create data channel if we're the host
    if (_isHost) {
      _dataChannel = await _peerConnection!.createDataChannel(
        'game',
        RTCDataChannelInit()..ordered = true,
      );
      _setupDataChannel();
    }
  }

  /// Setup data channel message handling
  void _setupDataChannel() {
    _dataChannel!.onDataChannelState = (state) {
      _log.i('📡 Data channel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen && !_initialized) {
        _initialized = true;
        _log.i('🎉 Data channel opened - WebRTC ready!');
      }
    };

    _dataChannel!.onMessage = (message) {
      try {
        final data = jsonDecode(message.text) as Map<String, dynamic>;
        _handleCommand(data);
      } catch (e) {
        _log.e('❌ Error parsing WebRTC message: $e');
      }
    };
  }

  /// Handle incoming command
  void _handleCommand(Map<String, dynamic> command) {
    final type = command['type'] as String? ?? '';
    final senderId = command['sender_id'] as String? ?? 'unknown';
    final payload = command['payload'] as Map<String, dynamic>? ?? {};

    if (senderId == _deviceId) return;

    if (type == 'ping') {
      final pingTs = payload['ping_ts'] as int? ?? 0;
      sendCommand('pong', {
        'ping_ts': pingTs,
        'pong_ts': DateTime.now().millisecondsSinceEpoch,
      });
    } else if (type == 'pong') {
      final pingTs = payload['ping_ts'] as int? ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final rtt = now - pingTs;

      _rttSamples.add(rtt);
      if (_rttSamples.length > 10) {
        _rttSamples.removeAt(0);
      }

      _log.i('🏓 WebRTC Pong received, RTT = ${rtt}ms (avg: ${avgRtt.toStringAsFixed(1)}ms)');
    } else {
      _cmdCtrl.add({
        'type': type,
        'payload': payload,
        'sender_id': senderId,
        'timestamp': command['timestamp'],
      });

      _log.i('📥 WebRTC Command received: $type from ${senderId.substring(0, 8)}...');
    }
  }

  /// Send command
  Future<void> sendCommand(String type, Map<String, dynamic> payload) async {
    if (!isConnected) {
      _log.w('⚠️ Cannot send WebRTC command - not connected');
      return;
    }

    final deviceId = await _getDeviceId();

    try {
      final command = {
        'type': type,
        'payload': payload,
        'sender_id': deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (type == 'ping') {
        command['payload'] = {
          ...payload,
          'ping_ts': DateTime.now().millisecondsSinceEpoch,
        };
      }

      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(command)));
      _log.i('📤 Sent WebRTC command: $type');
    } catch (e) {
      _log.e('❌ Failed to send WebRTC command "$type": $e');
    }
  }

  /// Send ping
  Future<void> sendPing() async {
    await sendCommand('ping', {});
  }

  /// Listen for signaling messages
  void _listenForSignaling() {
    _signalSubscription = _signalRef!.child('messages').onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<Object?, Object?>?;
      if (data == null) return;

      final message = <String, dynamic>{};
      data.forEach((key, value) {
        if (key is String) {
          message[key] = value;
        }
      });

      final senderId = message['sender'] as String?;
      if (senderId == _deviceId) return;

      _handleSignalingMessage(message);
    });
  }

  /// Handle signaling messages
  Future<void> _handleSignalingMessage(Map<String, dynamic> message) async {
    final type = message['type'] as String?;

    switch (type) {
      case 'offer':
        _log.i('📨 Received offer');
        final desc = RTCSessionDescription(message['sdp'], 'offer');
        await _peerConnection!.setRemoteDescription(desc);
        await _createAnswer();
        break;
      case 'answer':
        _log.i('📨 Received answer');
        final desc = RTCSessionDescription(message['sdp'], 'answer');
        await _peerConnection!.setRemoteDescription(desc);
        break;
      case 'ice':
        _log.i('📨 Received ICE candidate');
        try {
          await _peerConnection!.addCandidate(RTCIceCandidate(
            message['candidate'] as String?,
            message['sdpMid'] as String?,
            message['sdpMLineIndex'] as int?,
          ));
        } catch (e) {
          _log.w('⚠️ Failed to add ICE candidate: $e');
        }
        break;
    }
  }

  /// Create offer
  Future<void> _createOffer() async {
    try {
      _log.i('📤 Creating offer');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      _log.i('📤 Offer created, sending via signaling');
      await _sendSignal('offer', {'sdp': offer.sdp});
      _log.i('📤 Offer sent successfully');
    } catch (e) {
      _log.e('❌ Failed to create offer: $e');
    }
  }

  /// Create answer
  Future<void> _createAnswer() async {
    try {
      _log.i('📤 Creating answer');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _log.i('📤 Answer created, sending via signaling');
      await _sendSignal('answer', {'sdp': answer.sdp});
      _log.i('📤 Answer sent successfully');
    } catch (e) {
      _log.e('❌ Failed to create answer: $e');
    }
  }

  /// Send signaling message
  Future<void> _sendSignal(String type, Map<String, dynamic> data) async {
    await _signalRef!.child('messages').push().set({
      'type': type,
      'sender': _deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...data,
    });
  }

  /// Dispose
  Future<void> dispose() async {
    _log.i('🔌 Disposing WebRTC service...');

    if (_initialized) {
      try {
        await sendCommand('leave', {
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        _log.e('Error sending leave command: $e');
      }
    }

    await _signalSubscription?.cancel();
    await _dataChannel?.close();
    await _peerConnection?.close();
    await _cmdCtrl.close();

    _initialized = false;
    _rttSamples.clear();

    _log.i('👋 WebRTC service disposed');
  }
}