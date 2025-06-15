import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import '../providers/island_settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IslandSettingsPanel extends ConsumerWidget {
  final VoidCallback? onClose;
  const IslandSettingsPanel({Key? key, this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(islandSettingsProvider);
    final notifier = ref.read(islandSettingsProvider.notifier);

    return Card(
      color: Colors.black.withOpacity(0.85),
      margin: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: onClose,
                ),
              ),
              _buildSlider(
                context,
                'Amplitude',
                settings.amplitude,
                1.0,
                2.0,
                notifier.setAmplitude,
              ),
              _buildSlider(
                context,
                'Wavelength',
                settings.wavelength,
                0.15,
                0.7,
                notifier.setWavelength,
              ),
              _buildSlider(
                context,
                'Bias',
                settings.bias,
                -1.0,
                0.2,
                notifier.setBias,
              ),
              _buildSlider(
                context,
                'Island Size',
                settings.islandRadius,
                0.4,
                2.0,
                notifier.setIslandRadius,
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Seed: ${settings.seed}',
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
                      onPressed: notifier.randomizeSeed,
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ));
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