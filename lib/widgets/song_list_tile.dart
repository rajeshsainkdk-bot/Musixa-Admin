import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../theme/app_colors.dart';
import '../providers/player_provider.dart';
import 'visualizer_bars.dart';

class SongListTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool isCurrent;

  const SongListTile({
    Key? key,
    required this.song,
    required this.onTap,
    this.isCurrent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary.withOpacity(0.12)
            : AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.accentCyan.withOpacity(0.4)
              : Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Thumbnail with Play overlay or active visualizer
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: song.coverUrl.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: song.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.music_note, color: AppColors.textMuted),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.music_note, color: AppColors.textMuted),
                                ),
                              )
                            : Container(
                                color: AppColors.card,
                                child: const Icon(Icons.music_note_rounded, color: AppColors.accentCyan),
                              ),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: VisualizerBars(
                            isPlaying: playerProvider.isPlaying,
                            maxHeight: 18,
                            barWidth: 3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),

                // Title and Artist info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withOpacity(0.12)),
                            ),
                            child: Text(
                              song.genre,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (song.subCategory != null &&
                              song.subCategory!.trim().isNotEmpty &&
                              song.subCategory!.trim().toLowerCase() != song.genre.trim().toLowerCase()) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.accentCyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.accentCyan.withOpacity(0.35)),
                              ),
                              child: Text(
                                song.subCategory!.trim(),
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Favorite Heart Button
                IconButton(
                  icon: Icon(
                    song.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: song.isFavorite ? AppColors.accentPink : AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    playerProvider.toggleFavorite(song);
                  },
                ),

                // Duration / Options
                Text(
                  song.formattedDuration,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),

                // CC Attribution info button
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 18),
                  tooltip: 'License Info',
                  onPressed: () => _showLicenseDetails(context, song),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLicenseDetails(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                  const Icon(Icons.verified_user_rounded, color: AppColors.accentCyan, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Legal Free Music Attribution',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontSize: 17),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Track: ${song.title}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              Text(
                'Artist: ${song.artist}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                'Catalog Source: ${song.source}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accentCyan.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'License: ${song.license}',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This audio is streamed legally under free Creative Commons / Public Domain licenses. Msixa Player strictly honors artist rights and open source royalty-free music distributions.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
