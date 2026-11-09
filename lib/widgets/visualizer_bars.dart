import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VisualizerBars extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double maxHeight;
  final double barWidth;

  const VisualizerBars({
    Key? key,
    required this.isPlaying,
    this.barCount = 4,
    this.maxHeight = 16.0,
    this.barWidth = 3.0,
  }) : super(key: key);

  @override
  State<VisualizerBars> createState() => _VisualizerBarsState();
}

class _VisualizerBarsState extends State<VisualizerBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VisualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (index) {
            final t = _controller.value;
            // Generate rhythmic phase-shifted height
            final phase = (index / widget.barCount) * pi;
            final dynamicFactor = widget.isPlaying
                ? (0.2 + 0.8 * sin(t * pi + phase).abs())
                : 0.2;
            final currentHeight = (widget.maxHeight * dynamicFactor).clamp(3.0, widget.maxHeight);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: widget.barWidth,
              height: currentHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentPink, AppColors.accentCyan],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(widget.barWidth),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        );
      },
    );
  }
}
