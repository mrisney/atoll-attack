// lib/debug/sync_debug.dart
import '../services/game_state_sync_service.dart';
import '../utils/app_logger.dart';

/// Debug utilities for testing game state synchronization
class SyncDebug {
  /// Force a full sync for testing
  static Future<void> forceFullSync() async {
    try {
      AppLogger.debug('🔧 DEBUG: Forcing full sync...');
      await GameStateSyncService.instance.forceFullSync();
      AppLogger.debug('✅ DEBUG: Full sync completed');
    } catch (e) {
      AppLogger.error('❌ DEBUG: Full sync failed', e);
    }
  }
  
  /// Get sync status for debugging
  static Map<String, dynamic> getSyncStatus() {
    try {
      return GameStateSyncService.instance.syncStatus;
    } catch (e) {
      AppLogger.error('❌ DEBUG: Could not get sync status', e);
      return {'error': e.toString()};
    }
  }
  
  /// Report a fake desync for testing
  static void reportFakeDesync() {
    try {
      AppLogger.debug('🔧 DEBUG: Reporting fake desync...');
      GameStateSyncService.instance.reportDesyncDetected('DEBUG: Fake desync for testing');
    } catch (e) {
      AppLogger.error('❌ DEBUG: Could not report fake desync', e);
    }
  }
  
  /// Print current sync status
  static void printSyncStatus() {
    final status = getSyncStatus();
    AppLogger.debug('🔍 SYNC STATUS:');
    status.forEach((key, value) {
      AppLogger.debug('  $key: $value');
    });
  }
}
