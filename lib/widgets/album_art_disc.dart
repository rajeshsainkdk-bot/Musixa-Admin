import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AlbumArtDisc extends StatefulWidget {
  final String imageUrl;
  final bool isPlaying;
  final double size;

  const AlbumArtDisc({
    Key? key,
    required this.imageUrl,
    required this.isPlaying,
    this.size = 280.0,
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient aura glow
          Container(
            width: widget.size * 1.15,
            height: widget.size * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(widget.isPlaying ? 0.45 : 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(widget.isPlaying ? 0.35 : 0.15),
                  blurRadius: 50,
                  spreadRadius: 5,
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
                  color: const Color(0xFF2A364F),
                  width: 3,
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
                        color: Colors.white.withOpacity(0.04),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: widget.size * 0.74,
                    height: widget.size * 0.74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Center Album Artwork Label
                  ClipOval(
                    child: SizedBox(
                      width: widget.size * 0.58,
                      height: widget.size * 0.58,
                      child: widget.imageUrl.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppColors.card,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accentCyan,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.card,
                                child: const Icon(Icons.music_note, color: AppColors.accentCyan, size: 40),
                              ),
                            )
                          : Container(
                              color: AppColors.card,
                              child: const Icon(Icons.music_note, color: AppColors.accentCyan, size: 40),
                            ),
                    ),
                  ),

                  // Center Vinyl Spindle Hole
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.8),
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
