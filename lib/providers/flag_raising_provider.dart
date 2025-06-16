import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit_model.dart';
import '../game/island_game.dart';
import '../config.dart';

/// Provider to track flag raising progress for UI feedback
class FlagRaisingNotifier extends StateNotifier<FlagRaisingState> {
  FlagRaisingNotifier() : super(FlagRaisingState());

  void updateFlagRaisingStatus(UnitModel? captain, bool isAtApex, double progress) {
    if (captain == null) {
      state = FlagRaisingState();
      return;
    }

    state = FlagRaisingState(
      isRaisingFlag: captain.isRaisingFlag,
      flagRaiseProgress: progress,
      team: captain.team,
      isAtApex: isAtApex,
      hasPlantedFlag: captain.hasPlantedFlag,
    );
  }

  void reset() {
    state = FlagRaisingState();
  }
}

/// State class to track flag raising status
class FlagRaisingState {
  final bool isRaisingFlag;
  final double flagRaiseProgress;
  final Team? team;
  final bool isAtApex;
  final bool hasPlantedFlag;

  FlagRaisingState({
    this.isRaisingFlag = false,
    this.flagRaiseProgress = 0.0,
    this.team,
    this.isAtApex = false,
    this.hasPlantedFlag = false,
  });

  String get teamName => team == Team.blue ? 'Blue' : 'Red';
  Color get teamColor => team == Team.blue ? const Color(0xFF2196F3) : const Color(0xFFF44336);
  
  /// Get formatted progress percentage
  String get progressText => '${(flagRaiseProgress * 100).round()}%';
  
  /// Get time remaining in seconds
  String get timeRemaining {
    final secondsRemaining = (kFlagRaiseDuration * (1.0 - flagRaiseProgress)).round();
    return '$secondsRemaining sec';
  }
}

/// Provider for flag raising state
final flagRaisingProvider = StateNotifierProvider<FlagRaisingNotifier, FlagRaisingState>((ref) {
  return FlagRaisingNotifier();
});