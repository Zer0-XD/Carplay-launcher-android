import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../../domain/models/launcher_settings.dart';

abstract final class AppTheme {
  static ThemeData dark({Color? accent}) => _build(Brightness.dark, accent: accent);
  static ThemeData light({Color? accent}) => _build(Brightness.light, accent: accent);

  static ThemeData _build(Brightness brightness, {Color? accent}) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;
    final resolvedAccent = accent ?? c.accent;

    // MD3 ColorScheme derived from the resolved accent seed
    final scheme = ColorScheme.fromSeed(
      seedColor: resolvedAccent,
      brightness: brightness,
    ).copyWith(
      // Keep our hand-tuned surface colours for the dark theme
      surface: c.background,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceVariant,
      surfaceContainerHighest: c.surfaceVariant,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceMuted,
      outline: c.divider,
      outlineVariant: c.divider.withAlpha(120),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,

      // MD3 card style
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 1,
        shadowColor: c.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // MD3 FilledButton / ElevatedButton style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // MD3 icon
      iconTheme: IconThemeData(color: c.onSurface, size: 24),

      // MD3 divider
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),

      // Typography — use MD3 type scale
      textTheme: const TextTheme().apply(
        bodyColor: isDark ? AppColors.dark.onSurface : AppColors.light.onSurface,
        displayColor: isDark ? AppColors.dark.onSurface : AppColors.light.onSurface,
      ),
    );
  }

  static Color accentColorValue(AccentColor accentColor) {
    switch (accentColor) {
      case AccentColor.green:  return const Color(0xFF2E7D32);
      case AccentColor.orange: return const Color(0xFFE65100);
      case AccentColor.red:    return const Color(0xFFC62828);
      case AccentColor.purple: return const Color(0xFF6750A4);
      case AccentColor.teal:   return const Color(0xFF00695C);
      case AccentColor.blue:   return const Color(0xFF1565C0);
    }
  }
}
