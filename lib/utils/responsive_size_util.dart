import 'package:flutter/material.dart';

/// Utility class for responsive sizing throughout the game
class ResponsiveSizeUtil {
  /// Singleton instance
  static final ResponsiveSizeUtil _instance = ResponsiveSizeUtil._internal();
  factory ResponsiveSizeUtil() => _instance;
  ResponsiveSizeUtil._internal();

  /// Screen size
  Size? _screenSize;

  /// Initialize with screen size
  void init(Size size) {
    _screenSize = size;
  }

  /// Get screen size, throw error if not initialized
  Size get screenSize {
    if (_screenSize == null) {
      throw Exception('ResponsiveSizeUtil not initialized. Call init() first.');
    }
    return _screenSize!;
  }

  /// Check if device is in landscape mode
  bool get isLandscape => screenSize.width > screenSize.height;

  /// Get width percentage of screen width
  double widthPercent(double percent) => screenSize.width * (percent / 100);

  /// Get height percentage of screen height
  double heightPercent(double percent) => screenSize.height * (percent / 100);

  /// Get position based on screen percentages
  Offset position(double xPercent, double yPercent) {
    return Offset(widthPercent(xPercent), heightPercent(yPercent));
  }

  /// Get responsive font size
  double fontSize(double size) {
    // Base size on the smaller dimension for consistency
    final base = isLandscape ? screenSize.height : screenSize.width;
    return size * (base / 400); // 400 is a reference size
  }
}