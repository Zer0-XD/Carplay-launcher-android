import 'package:flutter/material.dart';
import '../../domain/models/launcher_settings.dart';

// ── Asset paths ───────────────────────────────────────────────────────────────

/// Returns the asset path for a photo wallpaper, or null for gradient styles.
String? backgroundAssetPath(BackgroundStyle style) {
  switch (style) {
    case BackgroundStyle.photo1: return 'assets/backgrounds/1.jpg';
    case BackgroundStyle.photo2: return 'assets/backgrounds/2.jpg';
    case BackgroundStyle.photo3: return 'assets/backgrounds/3.jpg';
    case BackgroundStyle.photo4: return 'assets/backgrounds/4.jpg';
    case BackgroundStyle.photo5: return 'assets/backgrounds/5.jpg';
    case BackgroundStyle.photo6: return 'assets/backgrounds/7.jpg';
    default: return null;
  }
}

bool isPhotoBackground(BackgroundStyle style) =>
    backgroundAssetPath(style) != null;

// ── Gradient decoration (used when no photo) ──────────────────────────────────

BoxDecoration gradientDecoration(BackgroundStyle style) {
  switch (style) {
    case BackgroundStyle.darkGradient:
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A10), Color(0xFF12121C), Color(0xFF080810)],
          stops: [0.0, 0.55, 1.0],
        ),
      );
    case BackgroundStyle.blueGradient:
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF03080F), Color(0xFF071528), Color(0xFF04101E)],
          stops: [0.0, 0.55, 1.0],
        ),
      );
    case BackgroundStyle.purpleGradient:
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08040F), Color(0xFF140920), Color(0xFF080410)],
          stops: [0.0, 0.55, 1.0],
        ),
      );
    case BackgroundStyle.solidDark:
      return const BoxDecoration(color: Color(0xFF09090B));
    case BackgroundStyle.solidLight:
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEEF0F6), Color(0xFFD8DCE8)],
        ),
      );
    default:
      return const BoxDecoration(color: Color(0xFF09090B));
  }
}

// ── Full background widget (photo or gradient) ────────────────────────────────

/// Drop-in widget that renders the correct background for [style].
/// Animates cross-fade when [style] changes.
class BackgroundWidget extends StatelessWidget {
  const BackgroundWidget({super.key, required this.style, required this.child});

  final BackgroundStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final assetPath = backgroundAssetPath(style);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: _BgLayer(key: ValueKey(style), style: style, assetPath: assetPath,
          child: child),
    );
  }
}

class _BgLayer extends StatelessWidget {
  const _BgLayer({
    super.key,
    required this.style,
    required this.assetPath,
    required this.child,
  });

  final BackgroundStyle style;
  final String? assetPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (assetPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath!,
            fit: BoxFit.cover,
            // Decode at screen resolution — avoids over-large texture on 2GB devices
            cacheWidth: 1280,
          ),
          // Dark scrim so UI elements remain readable over any photo
          Container(color: Colors.black.withAlpha(110)),
          child,
        ],
      );
    }
    return Container(
      decoration: gradientDecoration(style),
      child: child,
    );
  }
}

// ── Accent ────────────────────────────────────────────────────────────────────

Color accentColorValue(AccentColor accent) {
  switch (accent) {
    case AccentColor.blue:   return const Color(0xFF0A84FF);
    case AccentColor.green:  return const Color(0xFF30D158);
    case AccentColor.orange: return const Color(0xFFFF9F0A);
    case AccentColor.red:    return const Color(0xFFFF453A);
    case AccentColor.purple: return const Color(0xFFBF5AF2);
    case AccentColor.teal:   return const Color(0xFF5AC8FA);
  }
}
