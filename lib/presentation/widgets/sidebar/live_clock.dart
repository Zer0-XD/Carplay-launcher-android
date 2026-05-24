import 'package:flutter/material.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/services/clock_service.dart';

/// Live digital clock widget. Subscribes to the shared [ClockService] stream
/// so only one [Timer] exists app-wide regardless of how many clock widgets
/// are mounted.
class LiveClock extends StatelessWidget {
  const LiveClock({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return StreamBuilder<DateTime>(
      stream: ClockService.instance.stream,
      builder: (context, snap) {
        final now = snap.data ?? DateTime.now();
        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');
        return compact
            ? Text(
                '$hour:$minute',
                style: AppTextStyles.clockSmall.copyWith(color: color),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$hour:$minute',
                    style: AppTextStyles.clockLarge.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateLabel(now),
                    style: AppTextStyles.dateLabel.copyWith(
                      color: color.withAlpha(178),
                    ),
                  ),
                ],
              );
      },
    );
  }

  String _dateLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${days[d.weekday - 1]} ${months[d.month - 1]} ${d.day}';
  }
}
