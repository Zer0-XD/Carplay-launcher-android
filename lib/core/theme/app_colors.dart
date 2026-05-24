import 'package:flutter/material.dart';

/// Material Design 3 palette. Both dark and light variants share the same
/// semantic API so all widgets reference [AppColors] by name.
abstract final class AppColors {
  // ── Dark Theme (MD3 dark baseline) ────────────────────────────────────────
  static const dark = _AppColorSet(
    background: Color(0xFF1C1B1F),   // MD3 dark background
    surface: Color(0xFF2B2930),      // MD3 surface-container
    surfaceVariant: Color(0xFF49454F), // MD3 surface-variant
    onSurface: Color(0xFFE6E1E5),
    onSurfaceMuted: Color(0xFF938F99),
    accent: Color(0xFFD0BCFF),       // MD3 primary (purple)
    accentAlt: Color(0xFF6DD58C),    // MD3 tertiary (green)
    warning: Color(0xFFFFB4AB),
    sidebar: Color(0xFF211F26),
    divider: Color(0xFF49454F),
    cardShadow: Color(0x66000000),
  );

  // ── Light Theme (MD3 light baseline) ──────────────────────────────────────
  static const light = _AppColorSet(
    background: Color(0xFFFFFBFE),
    surface: Color(0xFFE6E0EC),      // MD3 surface-container
    surfaceVariant: Color(0xFFE7E0EC),
    onSurface: Color(0xFF1C1B1F),
    onSurfaceMuted: Color(0xFF49454F),
    accent: Color(0xFF6750A4),       // MD3 primary
    accentAlt: Color(0xFF625B71),
    warning: Color(0xFFB3261E),
    sidebar: Color(0xFFECE6F0),
    divider: Color(0xFFCAC4D0),
    cardShadow: Color(0x22000000),
  );
}

class _AppColorSet {
  const _AppColorSet({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.accent,
    required this.accentAlt,
    required this.warning,
    required this.sidebar,
    required this.divider,
    required this.cardShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color accent;
  final Color accentAlt;
  final Color warning;
  final Color sidebar;
  final Color divider;
  final Color cardShadow;
}
