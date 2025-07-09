// test/sync_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:atoll_attack/services/game_state_sync_service.dart';
import 'package:atoll_attack/services/rtdb_service.dart';
import 'package:atoll_attack/debug/sync_debug.dart';

void main() {
  group('Game State Sync Integration Tests', () {
    test('Sync service initialization', () {
      // This is a basic test to ensure the classes are properly structured
      expect(FirebaseRTDBService.instance, isNotNull);
      
      // Test debug utilities
      final status = SyncDebug.getSyncStatus();
      expect(status, isA<Map<String, dynamic>>());
    });
    
    test('Sync debug utilities', () {
      // Test that debug methods don't crash
      expect(() => SyncDebug.reportFakeDesync(), returnsNormally);
      expect(() => SyncDebug.printSyncStatus(), returnsNormally);
    });
  });
}
