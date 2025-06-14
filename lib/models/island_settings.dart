class IslandSettings {
  final double amplitude;
  final double wavelength;
  final double bias;
  final double islandRadius;
  final int seed;

  const IslandSettings({
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.islandRadius,
    required this.seed,
  });

  IslandSettings copyWith({
    double? amplitude,
    double? wavelength,
    double? bias,
    double? islandRadius,
    int? seed,
  }) {
    return IslandSettings(
      amplitude: amplitude ?? this.amplitude,
      wavelength: wavelength ?? this.wavelength,
      bias: bias ?? this.bias,
      islandRadius: islandRadius ?? this.islandRadius,
      seed: seed ?? this.seed,
    );
  }
}
