import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/unit_model.dart';

// Flag raising duration constant (since we can't import config.dart in this example)
const double kFlagRaiseDuration = 5.0; // 5 seconds to raise flag

class FlagRaiseComponent extends PositionComponent {
  final UnitModel captain;
  final Color teamColor;

  // Flag raising properties
  double _flagRaiseProgress = 0.0; // 0.0 to 1.0
  double _flagRaiseDuration = kFlagRaiseDuration; // From config
  bool _isRaisingFlag = false;
  bool _flagFullyRaised = false;

  // Visual properties
  double _flagWaveOffset = 0.0;
  double _progressBarWidth = 30.0;
  double _progressBarHeight = 4.0;

  // Flag pole and flag dimensions
  double _flagPoleHeight = 20.0;
  double _flagWidth = 12.0;
  double _flagHeight = 8.0;

  FlagRaiseComponent({
    required this.captain,
    required this.teamColor,
  }) : super(
          position: captain.position.clone(),
          size: Vector2(40, 30), // Size to contain flag and progress bar
          anchor: Anchor.center,
        );

  /// Start the flag raising process
  void startRaisingFlag() {
    if (!_isRaisingFlag && !_flagFullyRaised && captain.health > 0) {
      _isRaisingFlag = true;
      _flagRaiseProgress = 0.0;
      captain.hasPlantedFlag = false; // Reset until fully raised
    }
  }

  /// Stop the flag raising process (e.g., captain moves or takes damage)
  void stopRaisingFlag() {
    if (_isRaisingFlag && !_flagFullyRaised) {
      _isRaisingFlag = false;
      _flagRaiseProgress = 0.0;
      captain.hasPlantedFlag = false;
    }
  }

  /// Check if flag is fully raised
  bool get isFlagFullyRaised => _flagFullyRaised;

  /// Get current progress (0.0 to 1.0)
  double get progress => _flagRaiseProgress;

  @override
  void update(double dt) {
    super.update(dt);

    // Update position to follow captain
    position.setFrom(captain.position);

    // Update flag wave animation
    _flagWaveOffset += dt * 3.0;

    // Handle flag raising logic
    if (_isRaisingFlag && captain.health > 0) {
      _flagRaiseProgress += dt / _flagRaiseDuration;

      if (_flagRaiseProgress >= 1.0) {
        _flagRaiseProgress = 1.0;
        _flagFullyRaised = true;
        _isRaisingFlag = false;
        captain.hasPlantedFlag = true;
      }
    } else if (_isRaisingFlag && captain.health <= 0) {
      // Captain died while raising flag - stop the process
      stopRaisingFlag();
    }
  }

  @override
  void render(Canvas canvas) {
    // Only render if captain is alive
    if (captain.health <= 0) return;

    // Calculate flag position based on progress
    double flagCurrentHeight = _flagPoleHeight * _flagRaiseProgress;

    // Draw flag pole (always visible once raising starts or flag is raised)
    if (_isRaisingFlag || _flagFullyRaised) {
      _drawFlagPole(canvas);
    }

    // Draw flag (only if there's progress)
    if (_flagRaiseProgress > 0.0) {
      _drawFlag(canvas, flagCurrentHeight);
    }

    // Draw progress bar (only while raising, not when fully raised)
    if (_isRaisingFlag && !_flagFullyRaised) {
      _drawProgressBar(canvas);
    }

    // Draw victory sparkles if flag is fully raised
    if (_flagFullyRaised) {
      _drawVictoryEffects(canvas);
    }
  }

  void _drawFlagPole(Canvas canvas) {
    final Paint polePaint = Paint()
      ..color = Colors.brown.shade800
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw flag pole
    canvas.drawLine(
      Offset(size.x / 2, size.y / 2 + 5), // Start at captain's position
      Offset(size.x / 2, size.y / 2 + 5 - _flagPoleHeight),
      polePaint,
    );
  }

  void _drawFlag(Canvas canvas, double currentHeight) {
    // Flag position on the pole
    double flagX = size.x / 2;
    double flagY = size.y / 2 + 5 - currentHeight;

    // Create flag path with wave effect
    final Path flagPath = Path();

    // Flag wave based on progress and time
    double waveIntensity =
        _flagRaiseProgress * 0.7; // More wave when fully raised
    double wave1 = math.sin(_flagWaveOffset) * waveIntensity;
    double wave2 = math.sin(_flagWaveOffset + 1.0) * waveIntensity;

    // Draw flag with wavy right edge
    flagPath.moveTo(flagX, flagY);
    flagPath.lineTo(flagX + _flagWidth + wave1, flagY + 2);
    flagPath.lineTo(flagX + _flagWidth + wave2, flagY + _flagHeight - 2);
    flagPath.lineTo(flagX, flagY + _flagHeight);
    flagPath.close();

    // Fill flag with team color
    final Paint flagFillPaint = Paint()
      ..color = teamColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(flagPath, flagFillPaint);

    // Draw flag border
    final Paint flagBorderPaint = Paint()
      ..color = teamColor.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(flagPath, flagBorderPaint);

    // Add team symbol or letter on flag if fully raised
    if (_flagFullyRaised) {
      final String teamLetter = captain.team == Team.blue ? 'B' : 'R';

      final TextSpan textSpan = TextSpan(
        text: teamLetter,
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: Offset(0.5, 0.5),
              blurRadius: 1,
              color: Colors.black,
            ),
          ],
        ),
      );

      final TextPainter textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(
          flagX + _flagWidth / 2 - textPainter.width / 2,
          flagY + _flagHeight / 2 - textPainter.height / 2,
        ),
      );
    }
  }

  void _drawProgressBar(Canvas canvas) {
    // Progress bar position (above the flag pole)
    double barX = size.x / 2 - _progressBarWidth / 2;
    double barY = size.y / 2 + 5 - _flagPoleHeight - 8;

    // Background bar
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _progressBarWidth, _progressBarHeight),
        Radius.circular(_progressBarHeight / 2),
      ),
      backgroundPaint,
    );

    // Progress fill
    final Paint progressPaint = Paint()
      ..color = teamColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _progressBarWidth * _flagRaiseProgress,
            _progressBarHeight),
        Radius.circular(_progressBarHeight / 2),
      ),
      progressPaint,
    );

    // Progress bar border
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _progressBarWidth, _progressBarHeight),
        Radius.circular(_progressBarHeight / 2),
      ),
      borderPaint,
    );

    // Progress text
    final String progressText = '${(_flagRaiseProgress * 100).round()}%';
    final TextSpan textSpan = TextSpan(
      text: progressText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 8,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(0.5, 0.5),
            blurRadius: 2,
            color: Colors.black,
          ),
        ],
      ),
    );

    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        barX + _progressBarWidth / 2 - textPainter.width / 2,
        barY - textPainter.height - 2,
      ),
    );
  }

  void _drawVictoryEffects(Canvas canvas) {
    // Draw golden sparkles around the fully raised flag
    final Paint sparklePaint = Paint()
      ..color = Colors.yellow.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // Create sparkles that rotate around the flag
    for (int i = 0; i < 8; i++) {
      double angle = (i / 8.0) * 2 * math.pi + _flagWaveOffset;
      double sparkleX = size.x / 2 + math.cos(angle) * 15;
      double sparkleY = size.y / 2 - 5 + math.sin(angle) * 8;

      // Draw sparkle as small star
      _drawStar(canvas, Offset(sparkleX, sparkleY), 2.0, sparklePaint);
    }

    // Draw golden glow around flag
    final Paint glowPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 - 10),
      20,
      glowPaint,
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final Path starPath = Path();

    for (int i = 0; i < 5; i++) {
      double angle = (i * 2 * math.pi / 5) - math.pi / 2;
      double x = center.dx + math.cos(angle) * radius;
      double y = center.dy + math.sin(angle) * radius;

      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }

      // Inner point
      double innerAngle = angle + math.pi / 5;
      double innerX = center.dx + math.cos(innerAngle) * radius * 0.4;
      double innerY = center.dy + math.sin(innerAngle) * radius * 0.4;
      starPath.lineTo(innerX, innerY);
    }

    starPath.close();
    canvas.drawPath(starPath, paint);
  }
}
