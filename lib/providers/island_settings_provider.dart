import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/island_settings.dart';
import '../config.dart'; // Import your config file

class IslandSettingsNotifier extends StateNotifier<IslandSettings> {
  IslandSettingsNotifier()
      : super(const IslandSettings(
          amplitude: kDefaultAmplitude,
          wavelength: kDefaultWavelength,
          bias: kDefaultBias,
          islandRadius: kDefaultIslandRadius,
          seed: kDefaultSeed,
        ));

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
