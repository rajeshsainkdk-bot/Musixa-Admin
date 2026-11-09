import 'package:flutter/material.dart';

class AppColors {
  // Pure Obsidian & Deep Space Dark Palette
  static const Color background = Color(0xFF090D16);
  static const Color backgroundSecondary = Color(0xFF0F172A);
  static const Color surface = Color(0xFF131C2E);
  static const Color card = Color(0xFF1A243B);
  static const Color cardLight = Color(0xFF222F4C);

  // Glassmorphic Overlays
  static const Color glassSurface = Color(0xCC131C2E);
  static const Color glassBorder = Color(0x22FFFFFF);
  static const Color glassBorderGlow = Color(0x446366F1);

  // Vibrant Neon & Premium Accents
  static const Color primary = Color(0xFF6366F1); // Electric Indigo
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accentCyan = Color(0xFF06B6D4); // Neon Cyan
  static const Color accentPink = Color(0xFFEC4899); // Radiant Magenta
  static const Color accentAmber = Color(0xFFF59E0B); // Amber Glow
  static const Color accentEmerald = Color(0xFF10B981); // Emerald Pulse
  static const Color accentGreen = Color(0xFF10B981); // Emerald Green for offline

  // Text Hierarchy
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDark = Color(0xFF334155);

  // Functional Colors
  static const Color error = Color(0xFFEF4444);
  static const Color activeIcon = Color(0xFF38BDF8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkCyanGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFF6366F1), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF162035), Color(0xFF101726)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF312E81),
      Color(0xFF1E1B4B),
      Color(0xFF090D16),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const RadialGradient vinylGlow = RadialGradient(
    colors: [
      Color(0x556366F1),
      Color(0x2206B6D4),
      Colors.transparent,
    ],
    radius: 0.85,
  );
}
