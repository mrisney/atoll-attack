// terrain_rules.dart - Centralized configuration for terrain generation parameters
import 'dart:math' as math;
import 'package:flame/components.dart';

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

  const TerrainRules({
    this.deepWaterThreshold = 0.18,
    this.shallowWaterThreshold = 0.32,
    this.lowlandThreshold = 0.50,
    this.midlandThreshold = 0.70,
    this.peakRadius = 0.25,
    this.peakIntensity = 0.4,
    this.peakPositionVariance = 0.25,
    this.waterSpeedMultiplier = 0.0,
    this.sandSpeedMultiplier = 0.9,
    this.lowlandSpeedMultiplier = 0.8,
    this.uplandSpeedMultiplier = 0.6,
    this.peakSpeedMultiplier = 0.5,
    this.sandTransitionThreshold = 0.39,
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
      return 0.5 + ((elevation - midlandThreshold) / (1.0 - midlandThreshold)) * 0.5;
    }
  }
}