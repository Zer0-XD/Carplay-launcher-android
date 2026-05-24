import 'package:flutter/material.dart';
import '../../../data/services/system_stats_service.dart';
import '../../../domain/models/system_stats.dart';

/// Compact row of network, GPS, and signal-bar indicators.
/// Rebuilds only when [SystemStats] changes (every 2 s).
class SignalIndicators extends StatelessWidget {
  const SignalIndicators({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = Theme.of(context).colorScheme.primary;
    final green = Theme.of(context).colorScheme.secondary;

    return StreamBuilder<SystemStats>(
      stream: SystemStatsService.instance.stream,
      builder: (context, snap) {
        final stats = snap.data ?? const SystemStats();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stats.hasNetwork ? Icons.wifi : Icons.wifi_off,
              size: 18,
              color: stats.hasNetwork ? green : muted,
            ),
            const SizedBox(height: 6),
            Icon(
              stats.hasGps ? Icons.gps_fixed : Icons.gps_off,
              size: 18,
              color: stats.hasGps ? accent : muted,
            ),
            const SizedBox(height: 6),
            _SignalBars(bars: stats.signalBars, activeColor: green, inactiveColor: muted),
          ],
        );
      },
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({
    required this.bars,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int bars;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final active = i < bars;
        return Container(
          width: 4,
          height: 4.0 + i * 3.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
