import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/layout.dart';

/// Embeds a native Android app widget inside an MD3-styled card shell.
/// In edit mode a translucent tonal scrim is shown; drag/resize callbacks
/// are wired up for future free-position use but are currently unused
/// (the bento layout handles positioning at the slot level).
class AndroidWidgetCard extends StatelessWidget {
  const AndroidWidgetCard({
    super.key,
    required this.appWidgetId,
    required this.isEditing,
    required this.onLongPress,
    this.onMove,
    this.onResize,
  });

  final int appWidgetId;
  final bool isEditing;
  final VoidCallback onLongPress;
  final void Function(Offset delta)? onMove;
  final void Function(Offset delta)? onResize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Layout.cardRadius),
        color: scheme.surfaceContainerLow,
        border: Border.all(
          color: isEditing
              ? scheme.primary
              : scheme.outlineVariant.withAlpha(160),
          width: isEditing ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(isDark ? 50 : 25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Layout.cardRadius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Native Android widget
            AndroidView(
              viewType: 'com.zero.dashflow_launcher/widget_view',
              creationParams: {'appWidgetId': appWidgetId},
              creationParamsCodec: const StandardMessageCodec(),
              gestureRecognizers: const {},
            ),

            // Edit overlay
            if (isEditing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: onLongPress,
                  onPanUpdate: (d) => onMove?.call(d.delta),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(22),
                    ),
                    child: Center(
                      child: _EditHint(scheme: scheme),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPress: onLongPress,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditHint extends StatelessWidget {
  const _EditHint({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withAlpha(230),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withAlpha(120),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded,
              size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            'Tap to change',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
