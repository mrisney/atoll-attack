import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IslandSettingsPanel extends StatefulWidget {
  final double amplitude;
  final double wavelength;
  final double bias;
  final double islandRadius;
  final int seed;
  final ValueChanged<double> onAmplitudeChanged;
  final ValueChanged<double> onWavelengthChanged;
  final ValueChanged<double> onBiasChanged;
  final ValueChanged<double> onIslandRadiusChanged;
  final ValueChanged<int> onSeedChanged;
  final VoidCallback onRandomize;
  final VoidCallback onClose;

  const IslandSettingsPanel({
    Key? key,
    required this.amplitude,
    required this.wavelength,
    required this.bias,
    required this.islandRadius,
    required this.seed,
    required this.onAmplitudeChanged,
    required this.onWavelengthChanged,
    required this.onBiasChanged,
    required this.onIslandRadiusChanged,
    required this.onSeedChanged,
    required this.onRandomize,
    required this.onClose,
  }) : super(key: key);

  @override
  State<IslandSettingsPanel> createState() => _IslandSettingsPanelState();
}

class _IslandSettingsPanelState extends State<IslandSettingsPanel> {
  late double amplitude;
  late double wavelength;
  late double bias;
  late double islandRadius;
  late int seed;

  @override
  void initState() {
    super.initState();
    amplitude = widget.amplitude;
    wavelength = widget.wavelength;
    bias = widget.bias;
    islandRadius = widget.islandRadius;
    seed = widget.seed;
  }

  void _setAmplitude(double value) {
    setState(() => amplitude = value);
    widget.onAmplitudeChanged(value);
  }

  void _setWavelength(double value) {
    setState(() => wavelength = value);
    widget.onWavelengthChanged(value);
  }

  void _setBias(double value) {
    setState(() => bias = value);
    widget.onBiasChanged(value);
  }

  void _setIslandRadius(double value) {
    setState(() => islandRadius = value);
    widget.onIslandRadiusChanged(value);
  }

  void _setSeed(int value) {
    setState(() => seed = value);
    widget.onSeedChanged(value);
  }

  void _randomize() {
    widget.onRandomize();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.96),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: widget.onClose,
              ),
            ),
            _buildSlider(
                context, 'Amplitude', amplitude, 1.0, 2.0, _setAmplitude),
            _buildSlider(
                context, 'Wavelength', wavelength, 0.15, 0.7, _setWavelength),
            _buildSlider(context, 'Bias', bias, -1.0, 0.2, _setBias),
            _buildSlider(context, 'Island Size', islandRadius, 0.4, 1.2,
                _setIslandRadius),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Seed: $seed',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final newSeed =
                            DateTime.now().millisecondsSinceEpoch % 100000;
                        _setSeed(newSeed);
                      },
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _randomize,
                      child: const Icon(Icons.shuffle, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.blue.withOpacity(0.38)),
                ),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blue.shade400,
              inactiveTrackColor: Colors.blue.withOpacity(0.22),
              thumbColor: Colors.blue.shade300,
              overlayColor: Colors.blue.withOpacity(0.13),
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 100,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
