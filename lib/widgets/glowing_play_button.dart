import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlowingPlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onTap;
  final double size;

  const GlowingPlayButton({
    Key? key,
    required this.isPlaying,
    required this.onTap,
    this.isBuffering = false,
    this.size = 64.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBuffering ? null : onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.55),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.accentCyan.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Center(
          child: isBuffering
              ? SizedBox(
                  width: size * 0.42,
                  height: size * 0.42,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: size * 0.58,
                ),
        ),
      ),
    );
  }
}
