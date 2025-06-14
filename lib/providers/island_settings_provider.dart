import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/island_settings.dart';

class IslandSettingsNotifier extends StateNotifier<IslandSettings> {
  IslandSettingsNotifier()
      : super(const IslandSettings(
          amplitude: 1.2,
          wavelength: 0.22,
          bias: -0.4,
          islandRadius: 0.65,
          seed: 12345,
        ));

  void update(IslandSettings newSettings) => state = newSettings;

  void setAmplitude(double value) => state = state.copyWith(amplitude: value);
  void setWavelength(double value) => state = state.copyWith(wavelength: value);
  void setBias(double value) => state = state.copyWith(bias: value);
  void setIslandRadius(double value) =>
      state = state.copyWith(islandRadius: value);
  void setSeed(int value) => state = state.copyWith(seed: value);
  void randomizeSeed() => state =
      state.copyWith(seed: DateTime.now().millisecondsSinceEpoch % 100000);
}

final islandSettingsProvider =
    StateNotifierProvider<IslandSettingsNotifier, IslandSettings>(
  (ref) => IslandSettingsNotifier(),
);
