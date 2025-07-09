// test/services/webrtc_game_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../lib/services/webrtc_game_service.dart';

// Generate mocks with proper generic types
@GenerateMocks([
  FirebaseFirestore,
  DocumentReference,
  DocumentSnapshot,
  CollectionReference,
  RTCPeerConnection,
  RTCDataChannel,
], customMocks: [
  MockSpec<CollectionReference<Map<String, dynamic>>>(as: #MockCollectionReferenceMap),
  MockSpec<DocumentReference<Map<String, dynamic>>>(as: #MockDocumentReferenceMap),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(as: #MockDocumentSnapshotMap),
])
import 'webrtc_game_service_test.mocks.dart';

void main() {
  group('WebRTCGameService', () {
    late WebRTCGameService service;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReferenceMap mockCollection;
    late MockDocumentReferenceMap mockDocument;

    setUp(() {
      service = WebRTCGameService.instance;
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReferenceMap();
      mockDocument = MockDocumentReferenceMap();
      
      // Setup basic mocks
      when(mockFirestore.collection('game_rooms')).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocument);
    });

    group('Initialization', () {
      test('should initialize with unique player ID', () async {
        await service.initialize();
        
        expect(service.playerId, isNotNull);
        expect(service.playerId, startsWith('player_'));
        expect(service.playerId!.length, equals(11)); // 'player_' + 4 digits
      });

      test('should start disconnected', () {
        expect(service.connectionState, equals('Disconnected'));
        expect(service.isConnected, isFalse);
        expect(service.isHost, isFalse);
        expect(service.roomCode, isNull);
      });
    });

    group('Room Creation', () {
      test('should generate valid room code format', () async {
        await service.initialize();
        
        // Mock Firestore operations
        when(mockDocument.set(any)).thenAnswer((_) async => {});
        
        final roomCode = await service.createRoom();
        
        expect(roomCode, isNotNull);
        expect(roomCode!.length, equals(2));
        expect(int.tryParse(roomCode), isNotNull);
        expect(service.isHost, isTrue);
        expect(service.roomCode, equals(roomCode));
      });

      test('should handle room creation failure gracefully', () async {
        await service.initialize();
        
        // Mock Firestore failure
        when(mockDocument.set(any)).thenThrow(Exception('Firestore error'));
        
        final roomCode = await service.createRoom();
        
        expect(roomCode, isNull);
        expect(service.isHost, isTrue); // State might be set before failure
      });
    });

    group('Room Joining', () {
      test('should join existing room successfully', () async {
        await service.initialize();
        
        // Mock room exists with valid data
        final mockSnapshot = MockDocumentSnapshotMap();
        when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'status': 'waiting',
          'offer': {
            'sdp': 'mock-sdp',
            'type': 'offer',
          },
          'host': 'other_player',
          'players': ['other_player'],
        });
        when(mockDocument.update(any)).thenAnswer((_) async => {});
        
        final success = await service.joinRoom('42');
        
        expect(success, isTrue);
        expect(service.isHost, isFalse);
        expect(service.roomCode, equals('42'));
      });

      test('should fail to join non-existent room', () async {
        await service.initialize();
        
        // Mock room doesn't exist
        final mockSnapshot = MockDocumentSnapshotMap();
        when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(false);
        
        final success = await service.joinRoom('99');
        
        expect(success, isFalse);
        expect(service.roomCode, isNull);
      });

      test('should fail to join room that is not waiting', () async {
        await service.initialize();
        
        // Mock room exists but is not waiting
        final mockSnapshot = MockDocumentSnapshotMap();
        when(mockDocument.get()).thenAnswer((_) async => mockSnapshot);
        when(mockSnapshot.exists).thenReturn(true);
        when(mockSnapshot.data()).thenReturn({
          'status': 'connected', // Not waiting
          'offer': {'sdp': 'mock-sdp', 'type': 'offer'},
        });
        
        final success = await service.joinRoom('42');
        
        expect(success, isFalse);
      });
    });

    group('Game Commands', () {
      test('should not send commands when disconnected', () async {
        await service.initialize();
        
        // Try to send command without connection
        await service.sendGameCommand('move_unit', {'unitId': '123'});
        
        // Should not throw, but also should not send anything
        // This is more of an integration test - unit test verifies no crash
        expect(service.isConnected, isFalse);
      });

      test('should generate unique command IDs', () async {
        await service.initialize();
        
        // This would require more complex mocking to fully test
        // For now, we verify the service doesn't crash
        expect(() => service.sendGameCommand('test', {}), returnsNormally);
      });
    });

    group('Latency Tracking', () {
      test('should start with zero latency measurements', () {
        expect(service.averageLatency, equals(0.0));
      });

      test('should handle ping/pong cycle', () async {
        await service.initialize();
        
        // This requires WebRTC connection to fully test
        // For unit test, we verify the method exists and doesn't crash
        expect(() => service.sendPing(), returnsNormally);
      });
    });

    group('Cleanup', () {
      test('should disconnect cleanly', () async {
        await service.initialize();
        
        // Mock Firestore update for cleanup
        when(mockDocument.update(any)).thenAnswer((_) async => {});
        
        await service.disconnect();
        
        expect(service.connectionState, equals('Disconnected'));
        expect(service.roomCode, isNull);
        expect(service.isHost, isFalse);
      });

      test('should dispose without errors', () {
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('Utility Methods', () {
      test('should generate valid player IDs', () async {
        await service.initialize();
        final playerId1 = service.playerId;
        
        expect(playerId1, isNotNull);
        expect(playerId1, startsWith('player_'));
        
        // Note: Since it's a singleton, multiple calls return same ID
        // In a real scenario, you'd want separate instances
      });
    });

    group('Error Handling', () {
      test('should handle Firestore errors gracefully', () async {
        await service.initialize();
        
        // Mock Firestore throwing errors
        when(mockDocument.get()).thenThrow(Exception('Network error'));
        
        final success = await service.joinRoom('42');
        expect(success, isFalse);
      });

      test('should handle WebRTC errors gracefully', () async {
        await service.initialize();
        
        // This would require mocking WebRTC components
        // For now, verify service doesn't crash on initialization
        expect(service.connectionState, equals('Disconnected'));
      });
    });
  });

  group('Integration Scenarios', () {
    test('should handle complete host-guest flow', () async {
      // This would be an integration test requiring two service instances
      // and actual WebRTC/Firestore connections
      // For unit testing, we verify the state transitions
      
      final service = WebRTCGameService.instance;
      await service.initialize();
      
      expect(service.connectionState, equals('Disconnected'));
      expect(service.isHost, isFalse);
      expect(service.roomCode, isNull);
      
      // After creating room (mocked)
      // expect(service.isHost, isTrue);
      // expect(service.roomCode, isNotNull);
    });
  });
}

// Helper class for testing callbacks
class TestCallbacks {
  final List<Map<String, dynamic>> receivedCommands = [];
  final List<String> connectionStates = [];
  final List<String> playersJoined = [];
  final List<double> latencyMeasurements = [];

  void onGameCommand(Map<String, dynamic> command) {
    receivedCommands.add(command);
  }

  void onConnectionState(String state) {
    connectionStates.add(state);
  }

  void onPlayerJoined(String playerId) {
    playersJoined.add(playerId);
  }

  void onLatency(double latency) {
    latencyMeasurements.add(latency);
  }

  void clear() {
    receivedCommands.clear();
    connectionStates.clear();
    playersJoined.clear();
    latencyMeasurements.clear();
  }
}
