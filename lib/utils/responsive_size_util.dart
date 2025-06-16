import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flame/components.dart' show Vector2;

/// Utility class for responsive sizing throughout the game
class ResponsiveSizeUtil {
  /// Singleton instance
  static final ResponsiveSizeUtil _instance = ResponsiveSizeUtil._internal();
  factory ResponsiveSizeUtil() => _instance;
  ResponsiveSizeUtil._internal();

  /// Screen size
  Size? _screenSize;
  
  /// Device pixel ratio for high-DPI screens
  double _devicePixelRatio = 1.0;
  
  /// Base reference size for scaling calculations
  static const Size _referenceSize = Size(400, 900);

  /// Initialize with screen size
  void init(Size size, {double? devicePixelRatio}) {
    _screenSize = size;
    _devicePixelRatio = devicePixelRatio ?? 1.0;
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
  
  /// Get the smaller dimension (width or height)
  double get smallerDimension => math.min(screenSize.width, screenSize.height);
  
  /// Get the larger dimension (width or height)
  double get largerDimension => math.max(screenSize.width, screenSize.height);

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
    return size * (base / _referenceSize.width);
  }
  
  /// Get responsive padding based on screen size
  EdgeInsets responsivePadding({
    double horizontal = 4.0,
    double vertical = 4.0,
  }) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return EdgeInsets.symmetric(
      horizontal: horizontal * scaleFactor,
      vertical: vertical * scaleFactor,
    );
  }
  
  /// Get responsive radius for rounded corners
  double responsiveRadius(double radius) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return radius * scaleFactor;
  }
  
  /// Get responsive icon size
  double iconSize(double size) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return size * scaleFactor;
  }
  
  /// Calculate a responsive value based on screen size
  double responsiveValue(double value) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return value * scaleFactor;
  }
  
  /// Get a responsive size for a widget
  Size responsiveSize(double width, double height) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return Size(width * scaleFactor, height * scaleFactor);
  }
  
  /// Get a responsive Vector2 for game components
  Vector2 responsiveVector2(double x, double y) {
    final scaleFactor = smallerDimension / _referenceSize.width;
    return Vector2(x * scaleFactor, y * scaleFactor);
  }
}