import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';

class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SleepTimerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlayerProvider>(context);
    final activeMinutes = provider.sleepMinutesRemaining;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.bedtime_rounded, color: AppColors.accentCyan, size: 24),
              const SizedBox(width: 10),
              Text(
                'Sleep Timer',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              if (activeMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentCyan.withOpacity(0.4)),
                  ),
                  child: Text(
                    '$activeMinutes min left',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Playback will automatically pause once the countdown timer expires.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Presets Grid
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [15, 30, 45, 60, 90].map((mins) {
              final isSelected = activeMinutes > 0 && activeMinutes <= mins && activeMinutes > (mins - 15);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  provider.setSleepTimer(mins);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentCyan.withOpacity(0.2) : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.accentCyan : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Text(
                    '$mins Minutes',
                    style: TextStyle(
                      color: isSelected ? AppColors.accentCyan : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          if (activeMinutes > 0)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.timer_off_rounded, size: 20),
                label: const Text('Turn Off Sleep Timer'),
                onPressed: () {
                  provider.setSleepTimer(0);
                  Navigator.pop(context);
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
