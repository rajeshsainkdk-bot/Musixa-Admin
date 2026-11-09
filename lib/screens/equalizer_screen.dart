import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/equalizer_preset.dart';
import '../providers/player_provider.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({Key? key}) : super(key: key);

  static const List<String> _bandLabels = [
    '60 Hz\nBass',
    '230 Hz\nLow-Mid',
    '910 Hz\nMid',
    '3.6 kHz\nHigh-Mid',
    '14 kHz\nTreble',
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        final lang = LanguageService();
        return Consumer<PlayerProvider>(
          builder: (context, provider, child) {
            final gains = provider.bandGains;

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: Text(lang.t('sound_fx_title')),
                actions: [
                  TextButton(
                    onPressed: () {
                      provider.setEqPreset(EqualizerPreset.defaultPresets.first);
                    },
                    child: Text(
                      lang.t('reset_btn'),
                      style: const TextStyle(color: AppColors.accentCyan),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preset selector chips
                    Text(
                      lang.t('presets_title'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: EqualizerPreset.defaultPresets.length,
                    itemBuilder: (context, index) {
                      final preset = EqualizerPreset.defaultPresets[index];
                      final isSelected = provider.currentEqPreset.name == preset.name;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(preset.name),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              provider.setEqPreset(preset);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),

                // Visual Graphic Equalizer Sliders Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('+10 dB', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text('0 dB', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          Text('-10 dB', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 5 Vertical Sliders
                      SizedBox(
                        height: 200,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (index) {
                            final gain = (index < gains.length) ? gains[index] : 0.0;

                            return Column(
                              children: [
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: AppColors.accentCyan,
                                        inactiveTrackColor: AppColors.cardLight,
                                        thumbColor: Colors.white,
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      ),
                                      child: Slider(
                                        value: gain.clamp(-10.0, 10.0),
                                        min: -10.0,
                                        max: 10.0,
                                        onChanged: (newVal) {
                                          provider.updateBandGain(index, newVal);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _bandLabels[index],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Audio Quality & Catalog License Details Card
                const Text(
                  'STREAMING & COMPLIANCE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.high_quality_rounded, color: AppColors.accentCyan),
                        title: const Text('Stream Bitrate', style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: const Text('High Quality 320 kbps MP3 Stream', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20),
                      ),
                      const Divider(color: Color(0x1AFFFFFF)),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.copyright_rounded, color: AppColors.primaryLight),
                        title: const Text('Catalog Licensing', style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: const Text(
                          'Legal Creative Commons (CC-BY / CC0 / SA). No unauthorized YouTube scraping.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }
}
