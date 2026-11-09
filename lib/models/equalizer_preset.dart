class EqualizerPreset {
  final String name;
  final List<double> bandGains; // 5 bands in dB (-10.0 to +10.0)
  // Bands: 60Hz (Sub Bass), 230Hz (Bass), 910Hz (Mids), 3.6kHz (Upper Mids), 14kHz (Treble)

  const EqualizerPreset({
    required this.name,
    required this.bandGains,
  });

  static const List<EqualizerPreset> defaultPresets = [
    EqualizerPreset(
      name: 'Flat',
      bandGains: [0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    EqualizerPreset(
      name: 'Bass Boost',
      bandGains: [7.0, 5.0, 0.5, -1.0, 1.0],
    ),
    EqualizerPreset(
      name: 'Vocal Clarity',
      bandGains: [-2.0, 1.0, 6.0, 4.0, 2.0],
    ),
    EqualizerPreset(
      name: 'Electronic / EDM',
      bandGains: [6.0, 3.5, -1.5, 3.0, 5.5],
    ),
    EqualizerPreset(
      name: 'Rock & Metal',
      bandGains: [4.5, 2.0, -2.0, 3.0, 4.5],
    ),
    EqualizerPreset(
      name: 'Cyber Chill',
      bandGains: [3.0, 2.0, 0.0, 1.5, 3.0],
    ),
    EqualizerPreset(
      name: 'Acoustic',
      bandGains: [2.5, 1.5, 3.0, 2.5, 2.0],
    ),
  ];
}
