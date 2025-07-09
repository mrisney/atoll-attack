// lib/utils/app_logger.dart

import 'package:logger/logger.dart';

/// Centralized logger configuration for the entire app
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Get the app logger instance
  static Logger get instance => _logger;

  /// Log debug message
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal error message
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// Log game-specific events with emoji prefixes
  static void game(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i('🎮 $message', error: error, stackTrace: stackTrace);
  }

  /// Log multiplayer-specific events
  static void multiplayer(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i('🌐 $message', error: error, stackTrace: stackTrace);
  }

  /// Log WebRTC-specific events
  static void webrtc(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i('📡 $message', error: error, stackTrace: stackTrace);
  }

  /// Log command-specific events
  static void command(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d('⚡ $message', error: error, stackTrace: stackTrace);
  }

  /// Log UI-specific events
  static void ui(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d('🎨 $message', error: error, stackTrace: stackTrace);
  }
}
