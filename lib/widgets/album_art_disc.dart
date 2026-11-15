import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song.dart';
import '../services/song_artwork_resolver.dart';
import '../theme/app_colors.dart';

/// Studio Turntable Album Art Disc with Dynamic Theme Sync
/// Supports live spinning vinyl animation, dynamic ambient aura glow matching the song theme,
/// and automatically generated title-matched studio artwork that never displays generic placeholders.
class AlbumArtDisc extends StatefulWidget {
  final String imageUrl;
  final bool isPlaying;
  final double size;
  final Song? song;
  final String? title;
  final String? artist;
  final String? genre;

  const AlbumArtDisc({
    Key? key,
    required this.imageUrl,
    required this.isPlaying,
    this.size = 280.0,
    this.song,
    this.title,
    this.artist,
    this.genre,
  }) : super(key: key);

  @override
  State<AlbumArtDisc> createState() => _AlbumArtDiscState();
}

class _AlbumArtDiscState extends State<AlbumArtDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AlbumArtDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  SongThemeData get _currentTheme {
    if (widget.song != null) {
      return SongArtworkResolver.getThemeForSong(widget.song!);
    }
    return SongArtworkResolver.getThemeForTitle(
      widget.title ?? '',
      artist: widget.artist ?? '',
      genre: widget.genre,
    );
  }

  String get _displayTitle {
    final raw = widget.song?.title ?? widget.title ?? 'Musixa Admin';
    return raw.replaceAll(RegExp(r'\.(mp3|m4a|wav|aac|flac)$', caseSensitive: false), '').trim();
  }

  String get _displayArtist {
    final raw = widget.song?.artist ?? widget.artist ?? 'Artist';
    return raw.isNotEmpty ? raw : 'Musixa Music';
  }

  /// Authentic Title-Matched Studio Vinyl Center Label
  Widget _buildThemedCenterLabel(SongThemeData theme, double labelSize) {
    return Container(
      width: labelSize,
      height: labelSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient watermark icon
          Positioned(
            right: -labelSize * 0.10,
            bottom: -labelSize * 0.10,
            child: Icon(
              theme.icon,
              size: labelSize * 0.70,
              color: Colors.white.withOpacity(0.18),
            ),
          ),

          // Dark Vignette
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.85),
                ],
                stops: const [0.4, 0.8, 1.0],
              ),
            ),
          ),

          // Top Theme Tag Pill
          Positioned(
            top: labelSize * 0.12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.accentColor.withOpacity(0.5), width: 0.8),
              ),
              child: Text(
                theme.themeName.toUpperCase(),
                style: TextStyle(
                  color: theme.accentColor,
                  fontSize: labelSize * 0.055,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),

          // Central Typography (Song Title & Singer)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: labelSize * 0.14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: labelSize * 0.05),
                Text(
                  _displayTitle,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: labelSize * 0.085,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                SizedBox(height: labelSize * 0.02),
                Text(
                  _displayArtist,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: labelSize * 0.062,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;
    final labelSize = widget.size * 0.60;
    final effectiveUrl = widget.imageUrl.trim();
    final hasValidHttpUrl = effectiveUrl.startsWith('http') &&
        !SongArtworkResolver.isGenericMicUrl(effectiveUrl);
    final isLocalFile = (effectiveUrl.startsWith('/') || effectiveUrl.startsWith('file://')) &&
        !SongArtworkResolver.isGenericMicUrl(effectiveUrl);

    Widget centerContent;
    if (hasValidHttpUrl) {
      centerContent = CachedNetworkImage(
        imageUrl: effectiveUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildThemedCenterLabel(theme, labelSize),
        errorWidget: (_, __, ___) => _buildThemedCenterLabel(theme, labelSize),
      );
    } else if (isLocalFile) {
      final f = File(effectiveUrl.replaceFirst('file://', ''));
      if (f.existsSync()) {
        centerContent = Image.file(
          f,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildThemedCenterLabel(theme, labelSize),
        );
      } else {
        final fallbackUrl = widget.song?.displayCoverUrl ??
            SongArtworkResolver.resolveArtwork(
              title: widget.title ?? '',
              artist: widget.artist ?? '',
              genre: widget.genre,
            );
        centerContent = CachedNetworkImage(
          imageUrl: fallbackUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _buildThemedCenterLabel(theme, labelSize),
          errorWidget: (_, __, ___) => _buildThemedCenterLabel(theme, labelSize),
        );
      }
    } else {
      final autoUrl = widget.song?.displayCoverUrl ??
          SongArtworkResolver.resolveArtwork(
            title: widget.title ?? '',
            artist: widget.artist ?? '',
            genre: widget.genre,
          );
      centerContent = CachedNetworkImage(
        imageUrl: autoUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildThemedCenterLabel(theme, labelSize),
        errorWidget: (_, __, ___) => _buildThemedCenterLabel(theme, labelSize),
      );
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Dynamic Ambient Aura Glow synchronized with Song Theme
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: widget.size * 1.18,
            height: widget.size * 1.18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(widget.isPlaying ? 0.65 : 0.30),
                  blurRadius: 45,
                  spreadRadius: 12,
                ),
                BoxShadow(
                  color: theme.accentColor.withOpacity(widget.isPlaying ? 0.45 : 0.20),
                  blurRadius: 55,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),

          // Vinyl Turntable Base Body
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F141E),
                border: Border.all(
                  color: theme.accentColor.withOpacity(0.35),
                  width: 2.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 25,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle Vinyl Grooves Rings
                  Container(
                    width: widget.size * 0.88,
                    height: widget.size * 0.88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: widget.size * 0.76,
                    height: widget.size * 0.76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Center Album Artwork Label (Never generic placeholder!)
                  ClipOval(
                    child: SizedBox(
                      width: labelSize,
                      height: labelSize,
                      child: centerContent,
                    ),
                  ),

                  // Center Vinyl Spindle Hole
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(
                        color: theme.accentColor,
                        width: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
