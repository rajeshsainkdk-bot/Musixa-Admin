import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, provider, child) {
        final currentSong = provider.currentSong;
        if (currentSong == null) return const SizedBox.shrink();

        final progress = provider.totalDuration.inMilliseconds > 0
            ? (provider.currentPosition.inMilliseconds /
                    provider.totalDuration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (context, anim1, anim2) => const NowPlayingScreen(),
                transitionsBuilder: (context, anim1, anim2, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(position: anim1.drive(tween), child: child);
                },
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Thumbnail
                          Hero(
                            tag: 'current_song_art',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: currentSong.coverUrl.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: currentSong.coverUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.card,
                                          child: const Icon(Icons.music_note, color: AppColors.accentCyan),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.card,
                                        child: const Icon(Icons.music_note, color: AppColors.accentCyan),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Title and Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Favorite Heart
                          IconButton(
                            icon: Icon(
                              currentSong.isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: currentSong.isFavorite
                                  ? AppColors.accentPink
                                  : AppColors.textMuted,
                              size: 22,
                            ),
                            onPressed: () => provider.toggleFavorite(currentSong),
                          ),

                          // Play / Pause Button
                          IconButton(
                            icon: provider.isBuffering
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentCyan,
                                    ),
                                  )
                                : Icon(
                                    provider.isPlaying
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: AppColors.accentCyan,
                                    size: 36,
                                  ),
                            onPressed: () => provider.togglePlayPause(),
                          ),

                          // Next Song Button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next_rounded,
                              color: AppColors.textPrimary,
                              size: 26,
                            ),
                            onPressed: () => provider.next(),
                          ),
                        ],
                      ),
                    ),

                    // Neon Progress Indicator Strip at bottom of mini player
                    SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.cardLight.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
