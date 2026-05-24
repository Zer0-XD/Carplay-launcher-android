import 'package:flutter/material.dart';
import '../../../core/constants/layout.dart';
import '../../../domain/models/app_info.dart';

/// Renders a single app icon inside a squircle container.
///
/// Icon bytes are decoded by [Image.memory] with [cacheWidth]/[cacheHeight]
/// capped at 96 px so the image codec never allocates a large bitmap on the
/// Dart heap — critical for 2 GB RAM devices.
class AppIconWidget extends StatelessWidget {
  const AppIconWidget({
    super.key,
    required this.app,
    this.size = Layout.appIconSizeDefault,
    this.onTap,
    this.onLongPress,
    this.showEditBadge = false,
  });

  final AppInfo app;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showEditBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _icon(scheme),
          if (showEditBadge) _editBadge(),
        ],
      ),
    );
  }

  Widget _icon(ColorScheme scheme) {
    final bytes = app.iconBytes;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: bytes != null
            ? Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 96,
                cacheHeight: 96,
                gaplessPlayback: true,
              )
            : Icon(Icons.apps, color: scheme.onSurfaceVariant, size: size * 0.5),
      ),
    );
  }

  Widget _editBadge() => Positioned(
        top: -4,
        right: -4,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(Icons.remove, color: Colors.white, size: 10),
        ),
      );
}

