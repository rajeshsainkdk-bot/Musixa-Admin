import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/audio_player_service.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/album_art_disc.dart';
import '../widgets/glowing_play_button.dart';
import '../widgets/sleep_timer_dialog.dart';
import 'equalizer_screen.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong;
        if (currentSong == null) {
          return const Scaffold(
            body: Center(
              child: Text('No song selected', style: TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }

        final maxDurationMs = provider.totalDuration.inMilliseconds.toDouble();
        final currentPosMs = provider.currentPosition.inMilliseconds.toDouble().clamp(0.0, maxDurationMs > 0 ? maxDurationMs : 1.0);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              // Ambient Background Glow Blob
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 100,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentCyan.withOpacity(0.15),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.15),
                        blurRadius: 100,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),

              // Main Screen Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Top Navigation Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Column(
                            children: [
                              Text(
                                currentSong.isOffline ? 'OFFLINE DEVICE AUDIO' : 'PLAYING FROM STREAM',
                                style: TextStyle(
                                  color: currentSong.isOffline ? AppColors.accentGreen : AppColors.accentCyan.withOpacity(0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentSong.source,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.graphic_eq_rounded, color: AppColors.textPrimary),
                                tooltip: 'Equalizer',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.bedtime_rounded,
                                  color: provider.sleepMinutesRemaining > 0
                                      ? AppColors.accentCyan
                                      : AppColors.textPrimary,
                                ),
                                tooltip: 'Sleep Timer',
                                onPressed: () => SleepTimerDialog.show(context),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Center Vinyl / Album Art Disc
                      AlbumArtDisc(
                        imageUrl: currentSong.displayCoverUrl,
                        isPlaying: provider.isPlaying,
                        size: MediaQuery.of(context).size.width * 0.70,
                      ),

                      const Spacer(),

                      // Track Metadata & Favorite
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      currentSong.artist,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: Text(
                                        currentSong.license.split(' ').take(2).join(' '),
                                        style: const TextStyle(
                                          color: AppColors.accentCyan,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              currentSong.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: currentSong.isFavorite
                                  ? AppColors.accentPink
                                  : AppColors.textMuted,
                              size: 28,
                            ),
                            onPressed: () => provider.toggleFavorite(currentSong),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Smooth Scrubbing Bar & Timers with Drag-Freeze - reactive StreamBuilder
                      StreamBuilder<Duration>(
                        stream: provider.positionStream,
                        initialData: provider.currentPosition,
                        builder: (context, snapshot) {
                          final pos = snapshot.data ?? provider.currentPosition;
                          return AudioScrubberBar(
                            currentPosition: pos,
                            totalDuration: provider.totalDuration,
                            onSeek: (seekPos) => provider.seek(seekPos),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Main Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle
                          IconButton(
                            icon: Icon(
                              Icons.shuffle_rounded,
                              color: provider.isShuffle
                                  ? AppColors.accentCyan
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                            onPressed: () => provider.toggleShuffle(),
                          ),

                          // Previous
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous_rounded,
                              color: AppColors.textPrimary,
                              size: 38,
                            ),
                            onPressed: () => provider.previous(),
                          ),

                          // Glowing Play / Pause FAB
                          GlowingPlayButton(
                            isPlaying: provider.isPlaying,
                            isBuffering: provider.isBuffering,
                            size: 68,
                            onTap: () => provider.togglePlayPause(),
                          ),

                          // Next
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.textPrimary,
                              size: 38,
                            ),
                            onPressed: () => provider.next(),
                          ),

                          // Repeat Mode (Off, All, One)
                          IconButton(
                            icon: Icon(
                              provider.repeatMode == RepeatMode.one
                                  ? Icons.repeat_one_rounded
                                  : Icons.repeat_rounded,
                              color: provider.repeatMode != RepeatMode.off
                                  ? AppColors.accentCyan
                                  : AppColors.textMuted,
                              size: 24,
                            ),
                            onPressed: () => provider.toggleRepeat(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Utility footer: Speed Selector and Queue
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Speed Pill
                          PopupMenuButton<double>(
                            initialValue: provider.speed,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (spd) => provider.setSpeed(spd),
                            itemBuilder: (ctx) => [0.75, 1.0, 1.25, 1.5, 2.0].map((spd) {
                              return PopupMenuItem(
                                value: spd,
                                child: Text(
                                  '${spd}x Speed',
                                  style: TextStyle(
                                    color: provider.speed == spd
                                        ? AppColors.accentCyan
                                        : AppColors.textPrimary,
                                    fontWeight: provider.speed == spd ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.speed_rounded, size: 16, color: AppColors.accentCyan),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${provider.speed}x',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Current Queue Counter & Sheet
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showQueueBottomSheet(context, provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.queue_music_rounded, size: 16, color: AppColors.accentCyan),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Queue (${provider.queue.length})',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQueueBottomSheet(BuildContext context, PlayerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Playing Queue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${provider.queue.length} Tracks',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.queue.length,
                  itemBuilder: (context, index) {
                    final song = provider.queue[index];
                    final isCurrent = provider.currentSong?.id == song.id;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? AppColors.accentCyan : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: Text(
                        song.formattedDuration,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      onTap: () {
                        provider.playSong(song, queueContext: provider.queue);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AudioScrubberBar extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<Duration> onSeek;

  const AudioScrubberBar({
    Key? key,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
  }) : super(key: key);

  @override
  State<AudioScrubberBar> createState() => _AudioScrubberBarState();
}

class _AudioScrubberBarState extends State<AudioScrubberBar> {
  double? _dragValue;
  bool _isDragging = false;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.totalDuration.inMilliseconds.toDouble();
    final actualPosMs = widget.currentPosition.inMilliseconds.toDouble();
    final clampedPosMs = actualPosMs.clamp(0.0, maxMs > 0 ? maxMs : 1.0);
    final sliderVal = (_isDragging && _dragValue != null) ? _dragValue! : clampedPosMs;

    final displayPos = (_isDragging && _dragValue != null)
        ? Duration(milliseconds: _dragValue!.toInt())
        : widget.currentPosition;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            trackHeight: 4.0,
            activeTrackColor: AppColors.accentCyan,
            inactiveTrackColor: AppColors.cardLight,
            thumbColor: Colors.white,
            overlayColor: AppColors.accentCyan.withOpacity(0.25),
          ),
          child: Slider(
            value: sliderVal.clamp(0.0, maxMs > 0 ? maxMs : 1.0),
            min: 0.0,
            max: maxMs > 0 ? maxMs : 1.0,
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              final target = Duration(milliseconds: val.toInt());
              widget.onSeek(target);
              setState(() {
                _isDragging = false;
                _dragValue = null;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(displayPos),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(widget.totalDuration),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

