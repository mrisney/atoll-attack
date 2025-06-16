// terrain_rules.dart - Centralized configuration for terrain generation parameters
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A centralized configuration class for terrain generation rules
class TerrainRules {
  // Elevation band thresholds
  final double deepWaterThreshold;
  final double shallowWaterThreshold;
  final double lowlandThreshold;
  final double midlandThreshold;

  // Peak generation parameters
  final double peakRadius;
  final double peakIntensity;
  final double peakPositionVariance;

  // Movement speed multipliers
  final double waterSpeedMultiplier;
  final double sandSpeedMultiplier;
  final double lowlandSpeedMultiplier;
  final double uplandSpeedMultiplier;
  final double peakSpeedMultiplier;

  // Terrain transition thresholds
  final double sandTransitionThreshold;

  // Contour rendering configuration
  final Map<String, Color> contourColors;
  final Map<String, double> contourThresholds;
  final Map<String, int> elevationLabels;
  final double contourStrokeWidth;
  final double coastlineStrokeWidth;

  // Noise generation parameters
  final int noiseLayers;
  final double noiseAmplitudeDecay;
  final double noiseFrequencyGain;
  final double noiseRotationAngle;

  const TerrainRules({
    // Elevation thresholds
    this.deepWaterThreshold = 0.18,
    this.shallowWaterThreshold = 0.32,
    this.lowlandThreshold = 0.50,
    this.midlandThreshold = 0.70,

    // Peak parameters
    this.peakRadius = 0.25,
    this.peakIntensity = 0.4,
    this.peakPositionVariance = 0.25,

    // Movement speeds
    this.waterSpeedMultiplier = 0.0,
    this.sandSpeedMultiplier = 0.9,
    this.lowlandSpeedMultiplier = 0.8,
    this.uplandSpeedMultiplier = 0.6,
    this.peakSpeedMultiplier = 0.5,
    this.sandTransitionThreshold = 0.39,

    // Rendering configuration
    this.contourColors = const {
      'coastline': Color(0xFF1565C0), // Blue 800
      'shallow': Color(0xFF81C784), // Green 300
      'midland': Color(0xFFFFB74D), // Orange 300
      'highland': Color(0xFF8D6E63), // Brown 300
    },
    this.contourThresholds = const {
      'coastline': 0.32,
      'shallow': 0.18,
      'midland': 0.50,
      'highland': 0.70,
    },
    this.elevationLabels = const {
      'shallow': 100,
      'midland': 300,
      'highland': 500,
    },
    this.contourStrokeWidth = 1.5,
    this.coastlineStrokeWidth = 2.5,

    // Noise parameters
    this.noiseLayers = 5,
    this.noiseAmplitudeDecay = 0.5,
    this.noiseFrequencyGain = 2.0,
    this.noiseRotationAngle = 0.5,
  });

  /// Get the elevation band (0-4) for a given elevation value
  int getElevationBand(double elevation) {
    if (elevation <= deepWaterThreshold) return 0; // Deep water
    if (elevation <= shallowWaterThreshold) return 1; // Shallow water
    if (elevation < lowlandThreshold) return 2; // Low land
    if (elevation < midlandThreshold) return 3; // Mid elevation
    return 4; // High peaks
  }

  /// Get movement speed multiplier for a given elevation
  double getMovementSpeedMultiplier(double elevation) {
    if (elevation <= shallowWaterThreshold) return waterSpeedMultiplier;
    if (elevation < sandTransitionThreshold) return sandSpeedMultiplier;
    if (elevation < lowlandThreshold) return lowlandSpeedMultiplier;
    if (elevation < midlandThreshold) return uplandSpeedMultiplier;
    return peakSpeedMultiplier;
  }

  /// Generate a peak position based on a seed
  Vector2 generatePeakPosition(int seed) {
    final rng = math.Random(seed);
    return Vector2(
      (rng.nextDouble() * peakPositionVariance * 2 - peakPositionVariance),
      (rng.nextDouble() * peakPositionVariance * 2 - peakPositionVariance),
    );
  }

  /// Calculate terrain difficulty factor based on elevation (0.0-1.0)
  /// Higher values mean more difficult terrain to traverse
  double getTerrainDifficulty(double elevation) {
    if (elevation <= shallowWaterThreshold) {
      // Water is impassable
      return 1.0;
    } else if (elevation < sandTransitionThreshold) {
      // Beach/sand - slightly difficult
      return 0.2;
    } else if (elevation < lowlandThreshold) {
      // Lowlands - easy to traverse
      return 0.1;
    } else if (elevation < midlandThreshold) {
      // Uplands - moderately difficult
      return 0.4;
    } else {
      // Peaks - very difficult
      // Scale difficulty based on how high the elevation is
      return 0.5 +
          ((elevation - midlandThreshold) / (1.0 - midlandThreshold)) * 0.5;
    }
  }

  /// Get terrain type name for a given elevation
  String getTerrainTypeName(double elevation) {
    if (elevation <= deepWaterThreshold) return 'deep_water';
    if (elevation <= shallowWaterThreshold) return 'shallow_water';
    if (elevation < sandTransitionThreshold) return 'beach';
    if (elevation < lowlandThreshold) return 'lowland';
    if (elevation < midlandThreshold) return 'upland';
    return 'peak';
  }

  /// Check if elevation represents water
  bool isWater(double elevation) {
    return elevation <= shallowWaterThreshold;
  }

  /// Check if elevation represents land
  bool isLand(double elevation) {
    return elevation > shallowWaterThreshold;
  }

  /// Get contour color for a terrain type
  Color getContourColor(String terrainType) {
    return contourColors[terrainType] ?? Colors.grey;
  }

  /// Get stroke width for a terrain type
  double getStrokeWidth(String terrainType) {
    return terrainType == 'coastline'
        ? coastlineStrokeWidth
        : contourStrokeWidth;
  }

  /// Generate fractal brownian motion noise parameters
  Map<String, dynamic> getNoiseParameters() {
    return {
      'layers': noiseLayers,
      'amplitudeDecay': noiseAmplitudeDecay,
      'frequencyGain': noiseFrequencyGain,
      'rotationAngle': noiseRotationAngle,
    };
  }

  /// Create a custom terrain rules configuration
  TerrainRules copyWith({
    double? deepWaterThreshold,
    double? shallowWaterThreshold,
    double? lowlandThreshold,
    double? midlandThreshold,
    double? peakRadius,
    double? peakIntensity,
    double? peakPositionVariance,
    Map<String, Color>? contourColors,
    Map<String, double>? contourThresholds,
    int? noiseLayers,
    double? noiseAmplitudeDecay,
  }) {
    return TerrainRules(
      deepWaterThreshold: deepWaterThreshold ?? this.deepWaterThreshold,
      shallowWaterThreshold:
          shallowWaterThreshold ?? this.shallowWaterThreshold,
      lowlandThreshold: lowlandThreshold ?? this.lowlandThreshold,
      midlandThreshold: midlandThreshold ?? this.midlandThreshold,
      peakRadius: peakRadius ?? this.peakRadius,
      peakIntensity: peakIntensity ?? this.peakIntensity,
      peakPositionVariance: peakPositionVariance ?? this.peakPositionVariance,
      contourColors: contourColors ?? this.contourColors,
      contourThresholds: contourThresholds ?? this.contourThresholds,
      noiseLayers: noiseLayers ?? this.noiseLayers,
      noiseAmplitudeDecay: noiseAmplitudeDecay ?? this.noiseAmplitudeDecay,
    );
  }
}
