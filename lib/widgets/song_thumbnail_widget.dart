import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/ai_artwork_service.dart';
import '../theme/app_colors.dart';
import 'visualizer_bars.dart';

class SongThumbnailWidget extends StatelessWidget {
  final Song song;
  final double size;
  final double borderRadius;
  final bool isPlaying;
  final bool showVisualizerWhenPlaying;

  const SongThumbnailWidget({
    Key? key,
    required this.song,
    this.size = 50,
    this.borderRadius = 12,
    this.isPlaying = false,
    this.showVisualizerWhenPlaying = true,
  }) : super(key: key);

  /// Generates deterministic, vibrant studio gradient pairs based on song metadata
  static List<Color> getGradientForSong(Song song) {
    final genreLower = song.genre.toLowerCase();
    final titleLower = song.title.toLowerCase();

    if (genreLower.contains('rajasthan') || genreLower.contains('marwadi')) {
      return const [Color(0xFFFF5722), Color(0xFFFF9800), Color(0xFFFFC107)];
    } else if (genreLower.contains('bhakti') ||
        genreLower.contains('ram') ||
        genreLower.contains('shyam') ||
        genreLower.contains('krishna') ||
        titleLower.contains('hanuman') ||
        titleLower.contains('chalisa')) {
      return const [Color(0xFFE65100), Color(0xFFFF6D00), Color(0xFFFFD54F)];
    } else if (genreLower.contains('dj') || genreLower.contains('remix') || genreLower.contains('dance')) {
      return const [Color(0xFF7C4DFF), Color(0xFF00E5FF), Color(0xFF00B0FF)];
    } else if (genreLower.contains('haryanvi') || genreLower.contains('ragni')) {
      return const [Color(0xFF1B5E20), Color(0xFF00C853), Color(0xFF64DD17)];
    } else if (genreLower.contains('punjabi') || genreLower.contains('sufi')) {
      return const [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFFFF6D00)];
    } else if (genreLower.contains('bollywood') || genreLower.contains('romance')) {
      return const [Color(0xFF880E4F), Color(0xFFD81B60), Color(0xFFFF4081)];
    } else if (genreLower.contains('lo-fi') || genreLower.contains('ghazal')) {
      return const [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF3A86FF)];
    }

    final hash = (song.title + song.artist + song.genre).hashCode.abs();
    final palettes = [
      const [Color(0xFF0A192F), Color(0xFF00E5FF), Color(0xFF3B82F6)],
      const [Color(0xFF31103F), Color(0xFFEC4899), Color(0xFF8B5CF6)],
      const [Color(0xFF451A03), Color(0xFFF59E0B), Color(0xFFEF4444)],
      const [Color(0xFF022C22), Color(0xFF10B981), Color(0xFF06B6D4)],
      const [Color(0xFF1E1B4B), Color(0xFF8B5CF6), Color(0xFF6366F1)],
      const [Color(0xFF3E1F00), Color(0xFFFF6D00), Color(0xFFFFAB00)],
    ];
    return palettes[hash % palettes.length];
  }

  static IconData getIconForGenre(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('bhakti') || g.contains('ram') || g.contains('shyam') || g.contains('spiritual')) {
      return Icons.flare_rounded;
    } else if (g.contains('dj') || g.contains('remix')) {
      return Icons.speaker_group_rounded;
    } else if (g.contains('rajasthan')) {
      return Icons.wb_sunny_rounded;
    } else if (g.contains('lo-fi')) {
      return Icons.nightlight_round;
    } else if (g.contains('bollywood')) {
      return Icons.movie_filter_rounded;
    } else if (g.contains('punjabi') || g.contains('sufi')) {
      return Icons.audiotrack_rounded;
    }
    return Icons.album_rounded;
  }

  /// Professional, Studio-Grade AI Album Cover Template
  Widget _buildProceduralArt(BuildContext context) {
    final gradient = getGradientForSong(song);
    final icon = getIconForGenre(song.genre);
    final initial = song.title.trim().isNotEmpty ? song.title.trim()[0].toUpperCase() : 'M';
    final isLarge = size >= 65;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Vinyl Groove Texture
            Positioned.fill(
              child: CustomPaint(
                painter: _VinylGroovesPainter(),
              ),
            ),

            // Layer 2: Subtle Ambient Icon Watermark
            Positioned(
              right: -size * 0.12,
              bottom: -size * 0.12,
              child: Icon(
                icon,
                size: size * 0.7,
                color: Colors.white.withOpacity(0.12),
              ),
            ),

            // Layer 3: Studio Seal & Audio Quality Badge (Top Left)
            Positioned(
              top: isLarge ? 8 : 4,
              left: isLarge ? 8 : 4,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isLarge ? 5 : 3, vertical: isLarge ? 2 : 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'MASTER',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isLarge ? 7 : 5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            // Layer 4: Center Visual (Monogram or 3D Musical Waveform)
            if (!isLarge)
              Center(
                child: Container(
                  width: size * 0.52,
                  height: size * 0.52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.35),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.w900,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Layer 5: Large Cover Typography Layout (when size >= 65)
            if (isLarge) ...[
              Center(
                child: Container(
                  width: size * 0.45,
                  height: size * 0.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: Colors.white.withOpacity(0.9),
                      size: size * 0.24,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Detects legacy hardcoded microphone placeholder from Unsplash or generic fallbacks
  static bool isGenericMicUrl(String? url) {
    if (url == null || url.trim().isEmpty) return true;
    final u = url.trim().toLowerCase();
    return u.contains('1511671782779') ||
        u.contains('photo-1511671782779') ||
        u.contains('1493225457124') ||
        u.contains('placeholder') ||
        u.contains('default_cover') ||
        u == 'null';
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final url = song.coverUrl.trim();
    final effectiveHttpUrl = (url.startsWith('http') && !isGenericMicUrl(url))
        ? url
        : song.displayCoverUrl;

    if ((url.startsWith('/') || url.startsWith('file://')) && !isGenericMicUrl(url)) {
      final filePath = url.replaceFirst('file://', '');
      final f = File(filePath);
      if (f.existsSync()) {
        content = Image.file(
          f,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CachedNetworkImage(
            imageUrl: effectiveHttpUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildProceduralArt(context),
            errorWidget: (_, __, ___) => _buildProceduralArt(context),
          ),
        );
      } else {
        content = CachedNetworkImage(
          imageUrl: effectiveHttpUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildProceduralArt(context),
          errorWidget: (_, __, ___) => _buildProceduralArt(context),
        );
      }
    } else {
      content = CachedNetworkImage(
        imageUrl: effectiveHttpUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildProceduralArt(context),
        errorWidget: (_, __, ___) => _buildProceduralArt(context),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: size,
            height: size,
            child: content,
          ),
        ),
        if (isPlaying && showVisualizerWhenPlaying)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: VisualizerBars(
                isPlaying: true,
                maxHeight: size * 0.4,
                barWidth: 3,
              ),
            ),
          ),
      ],
    );
  }
}

/// Painter for authentic concentric vinyl record grooves
class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.65;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withOpacity(0.06);

    for (double r = size.width * 0.15; r < maxRadius; r += size.width * 0.08) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
