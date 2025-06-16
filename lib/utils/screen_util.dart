import 'package:flutter/material.dart';

/// Simple utility for responsive sizing
class ScreenUtil {
  static Size? _screenSize;
  
  /// Initialize with screen size
  static void init(Size size) {
    _screenSize = size;
  }
  
  /// Get screen size
  static Size getScreenSize(BuildContext context) {
    return _screenSize ?? MediaQuery.of(context).size;
  }
  
  /// Get position based on screen percentages
  static Offset getPosition(BuildContext context, double xPercent, double yPercent) {
    final size = getScreenSize(context);
    return Offset(
      size.width * (xPercent / 100),
      size.height * (yPercent / 100)
    );
  }
}