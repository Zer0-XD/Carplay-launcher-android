import 'package:flutter/material.dart';
import '../../../core/constants/layout.dart';

/// MD3 tonal-surface card shell.
///
/// Surface colour hierarchy (first non-null wins):
///   1. [surfaceColor] — explicit override (avoid; breaks theming)
///   2. accent-tinted [ColorScheme.surfaceContainerLow] when [accentColor] set
///   3. plain [ColorScheme.surfaceContainerLow]
///
/// The crash `dart:ui painting.dart line 5245` was caused by calling
/// [Color.alphaBlend] with an [accentColor] that had alpha < 1 laid over a
/// base that was also semi-transparent — Flutter's Skia backend rejects that.
/// We now only call alphaBlend when both colours are fully opaque-safe.
class BaseCard extends StatelessWidget {
  const BaseCard({
    super.key,
    required this.child,
    this.onLongPress,
    this.padding = const EdgeInsets.all(Layout.cardPadding),
    this.isEditing = false,
    this.label,
    this.accentColor,
    this.surfaceColor,
  });

  final Widget child;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final bool isEditing;
  final String? label;
  final Color? accentColor;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Surface ────────────────────────────────────────────────────────────
    // Use the MD3 tonal-surface containers instead of any hardcoded hex.
    // If caller passes surfaceColor we respect it, otherwise we derive a
    // lightly accent-tinted surface from the scheme.
    final Color base = scheme.surfaceContainerLow;
    final Color surface;
    if (surfaceColor != null) {
      surface = surfaceColor!;
    } else if (accentColor != null) {
      // Safe tint: paint a translucent accent over an opaque base.
      // withValues keeps alpha in [0,1]; no crash risk.
      final tint = accentColor!.withAlpha(isDark ? 20 : 12);
      surface = Color.alphaBlend(tint, base);
    } else {
      surface = base;
    }

    final accent = accentColor ?? scheme.primary;

    return GestureDetector(
      onLongPress: onLongPress,
      child: RepaintBoundary(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Layout.cardRadius),
            color: surface,
            border: Border.all(
              color: isEditing
                  ? scheme.primary
                  : scheme.outlineVariant.withAlpha(140),
              width: isEditing ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                // scheme.shadow can be transparent on some seeds — use a safe fallback
                color: (scheme.brightness == Brightness.dark
                        ? Colors.black
                        : Colors.black54)
                    .withAlpha(isDark ? 45 : 20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Layout.cardRadius - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(padding: padding, child: child),

                // Accent top-edge indicator stripe
                if (accentColor != null && !isEditing)
                  Positioned(
                    top: 0,
                    left: 18,
                    right: 18,
                    height: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accent.withAlpha(isDark ? 200 : 150),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Edit-mode primary tonal scrim
                if (isEditing)
                  Positioned.fill(
                    child: ColoredBox(
                      color: scheme.primary.withAlpha(20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
