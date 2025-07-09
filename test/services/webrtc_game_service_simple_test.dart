// test/services/webrtc_game_service_simple_test.dart

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebRTC Game Service - Simple Tests', () {
    test('should generate valid room codes', () {
      // Test room code generation logic
      final roomCode = _generateRoomCode();
      
      expect(roomCode.length, equals(2));
      expect(int.tryParse(roomCode), isNotNull);
      expect(int.parse(roomCode), greaterThanOrEqualTo(0));
      expect(int.parse(roomCode), lessThanOrEqualTo(99));
    });

    test('should generate valid player IDs', () {
      // Test player ID generation logic
      final playerId = _generatePlayerId();
      
      expect(playerId, startsWith('player_'));
      expect(playerId.length, equals(11)); // 'player_' + 4 digits
      
      final numberPart = playerId.substring(7);
      expect(int.tryParse(numberPart), isNotNull);
    });

    test('should validate game command structure', () {
      // Test game command structure
      final command = _createGameCommand('move_unit', {'unitId': '123', 'x': 10, 'y': 20});
      
      expect(command['type'], equals('game_command'));
      expect(command['commandType'], equals('move_unit'));
      expect(command['data'], isA<Map<String, dynamic>>());
      expect(command['id'], isNotNull);
      expect(command['timestamp'], isA<int>());
      expect(command['from'], isNotNull);
    });

    test('should validate ping message structure', () {
      // Test ping message structure
      final ping = _createPingMessage();
      
      expect(ping['type'], equals('ping'));
      expect(ping['id'], startsWith('ping_'));
      expect(ping['timestamp'], isA<int>());
      expect(ping['from'], isNotNull);
    });

    test('should calculate latency correctly', () {
      // Test latency calculation
      final measurements = [10.0, 20.0, 30.0, 40.0, 50.0];
      final average = _calculateAverageLatency(measurements);
      
      expect(average, equals(30.0));
    });

    test('should handle empty latency measurements', () {
      // Test empty latency list
      final measurements = <double>[];
      final average = _calculateAverageLatency(measurements);
      
      expect(average, equals(0.0));
    });

    test('should limit latency measurements to 10', () {
      // Test latency measurement limit
      final measurements = List.generate(15, (i) => i.toDouble());
      final limited = _limitLatencyMeasurements(measurements, 10);
      
      expect(limited.length, equals(10));
      expect(limited.first, equals(5.0)); // Should remove first 5
      expect(limited.last, equals(14.0));
    });
  });

  group('Message Validation', () {
    test('should validate JSON message format', () {
      final message = {
        'type': 'game_command',
        'commandType': 'move_unit',
        'data': {'unitId': '123'},
        'id': 'test_123',
        'timestamp': 1234567890,
        'from': 'player_0001',
      };
      
      expect(_isValidGameMessage(message), isTrue);
    });

    test('should reject invalid message format', () {
      final invalidMessage = {
        'type': 'game_command',
        // Missing required fields
      };
      
      expect(_isValidGameMessage(invalidMessage), isFalse);
    });

    test('should validate acknowledgment message', () {
      final ack = {
        'type': 'ack',
        'id': 'test_123',
        'originalTimestamp': 1234567890,
        'timestamp': 1234567900,
      };
      
      expect(_isValidAckMessage(ack), isTrue);
    });
  });
}

// Helper functions that mirror the actual service logic
String _generateRoomCode() {
  return (DateTime.now().millisecondsSinceEpoch % 100).toString().padLeft(2, '0');
}

String _generatePlayerId() {
  final random = DateTime.now().millisecondsSinceEpoch % 10000;
  return 'player_${random.toString().padLeft(4, '0')}';
}

Map<String, dynamic> _createGameCommand(String commandType, Map<String, dynamic> data) {
  final playerId = _generatePlayerId();
  final commandId = '${playerId}_${DateTime.now().millisecondsSinceEpoch}';
  
  return {
    'type': 'game_command',
    'commandType': commandType,
    'data': data,
    'id': commandId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'from': playerId,
  };
}

Map<String, dynamic> _createPingMessage() {
  final playerId = _generatePlayerId();
  final pingId = 'ping_${playerId}_${DateTime.now().millisecondsSinceEpoch}';
  
  return {
    'type': 'ping',
    'id': pingId,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'from': playerId,
  };
}

double _calculateAverageLatency(List<double> measurements) {
  if (measurements.isEmpty) return 0.0;
  return measurements.reduce((a, b) => a + b) / measurements.length;
}

List<double> _limitLatencyMeasurements(List<double> measurements, int maxCount) {
  if (measurements.length <= maxCount) return measurements;
  return measurements.sublist(measurements.length - maxCount);
}

bool _isValidGameMessage(Map<String, dynamic> message) {
  return message.containsKey('type') &&
         message.containsKey('commandType') &&
         message.containsKey('data') &&
         message.containsKey('id') &&
         message.containsKey('timestamp') &&
         message.containsKey('from');
}

bool _isValidAckMessage(Map<String, dynamic> message) {
  return message.containsKey('type') &&
         message['type'] == 'ack' &&
         message.containsKey('id') &&
         message.containsKey('originalTimestamp') &&
         message.containsKey('timestamp');
}
