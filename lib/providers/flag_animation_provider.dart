import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to control flag raising animation visibility
final flagRaisingAnimationProvider = StateProvider<bool>((ref) => true);

/// Provider to track flag raising progress for UI feedback
final flagRaisingProgressProvider = StateProvider<double>((ref) => 0.0);

/// Provider to track which team is currently raising a flag
final flagRaisingTeamProvider = StateProvider<String?>((ref) => null);