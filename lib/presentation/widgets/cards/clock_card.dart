import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/services/clock_service.dart';
import 'base_card.dart';

class ClockCard extends StatelessWidget {
  const ClockCard({super.key, this.isEditing = false, this.onLongPress, this.isLarge = false});

  final bool isEditing;
  final VoidCallback? onLongPress;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      isEditing: isEditing,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      accentColor: const Color(0xFF3B82F6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = (constraints.smallest.shortestSide / 200.0).clamp(0.5, 2.0);
          final wide = constraints.maxWidth > constraints.maxHeight * 1.3;
          return StreamBuilder<DateTime>(
            stream: ClockService.instance.stream,
            builder: (context, snap) {
              final now = snap.data ?? DateTime.now();
              return _ClockFace(now: now, s: s, wide: wide);
            },
          );
        },
      ),
    );
  }
}

class _ClockFace extends StatelessWidget {
  const _ClockFace({required this.now, required this.s, required this.wide});
  final DateTime now;
  final double s;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final sec = now.second.toString().padLeft(2, '0');
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateLabel = '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    if (wide) {
      return Padding(
        padding: EdgeInsets.all(16 * s),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(painter: _AnalogPainter(now: now, scheme: scheme)),
                ),
              ),
            ),
            SizedBox(width: 14 * s),
            Expanded(
              flex: 6,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$h:$m',
                        style: TextStyle(
                          fontSize: 48 * s,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                          height: 1.0,
                          color: scheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 4 * s),
                      Text(
                        ':$sec',
                        style: TextStyle(
                          fontSize: 20 * s,
                          fontWeight: FontWeight.w300,
                          height: 1.0,
                          color: const Color(0xFF3B82F6).withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6 * s),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 11 * s,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  _SecondsBar(second: now.second, s: s, scheme: scheme),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 12 * s),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(painter: _AnalogPainter(now: now, scheme: scheme)),
              ),
            ),
          ),
          SizedBox(height: 10 * s),
          Text(
            '$h:$m',
            style: TextStyle(
              fontSize: 36 * s,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.5,
              height: 1.0,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 10 * s,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8 * s),
        ],
      ),
    );
  }
}

// ── Seconds progress bar ──────────────────────────────────────────────────────

class _SecondsBar extends StatelessWidget {
  const _SecondsBar({required this.second, required this.s, required this.scheme});
  final int second;
  final double s;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LayoutBuilder(
        builder: (_, c) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Container(color: scheme.surfaceContainerHigh),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                width: c.maxWidth * (second / 59).clamp(0.0, 1.0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Analog painter ────────────────────────────────────────────────────────────

class _AnalogPainter extends CustomPainter {
  const _AnalogPainter({required this.now, required this.scheme});
  final DateTime now;
  final ColorScheme scheme;

  static const _accent = Color(0xFF3B82F6);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.92;

    // Face
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()..color = scheme.surfaceContainer,
    );
    // Rim
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Hour ticks
    final onSurface = scheme.onSurface;
    for (int i = 0; i < 60; i++) {
      final angle = (i * 6 - 90) * math.pi / 180;
      final isMajor = i % 5 == 0;
      final outer = r * 0.92;
      final inner = isMajor ? r * 0.76 : r * 0.86;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        Paint()
          ..color = isMajor
              ? onSurface.withAlpha(160)
              : onSurface.withAlpha(45)
          ..strokeWidth = isMajor ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Hour hand
    final hourAngle = ((now.hour % 12) + now.minute / 60) * 30 - 90;
    _drawHand(canvas, cx, cy,
        angle: hourAngle * math.pi / 180,
        length: r * 0.50,
        width: 4.0,
        color: onSurface);

    // Minute hand
    final minuteAngle = (now.minute + now.second / 60) * 6 - 90;
    _drawHand(canvas, cx, cy,
        angle: minuteAngle * math.pi / 180,
        length: r * 0.70,
        width: 2.5,
        color: onSurface);

    // Second hand
    final secondAngle = now.second * 6.0 - 90;
    _drawHand(canvas, cx, cy,
        angle: secondAngle * math.pi / 180,
        length: r * 0.78,
        width: 1.2,
        color: _accent,
        tail: r * 0.18);

    // Center cap
    canvas.drawCircle(Offset(cx, cy), 5.0,
        Paint()..color = scheme.surfaceContainerHighest);
    canvas.drawCircle(Offset(cx, cy), 3.5,
        Paint()..color = _accent);
    canvas.drawCircle(Offset(cx, cy), 1.8,
        Paint()..color = onSurface);
  }

  void _drawHand(Canvas canvas, double cx, double cy, {
    required double angle,
    required double length,
    required double width,
    required Color color,
    double tail = 0,
  }) {
    canvas.drawLine(
      Offset(cx - tail * math.cos(angle), cy - tail * math.sin(angle)),
      Offset(cx + length * math.cos(angle), cy + length * math.sin(angle)),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_AnalogPainter old) =>
      old.now.second != now.second ||
      old.now.minute != now.minute ||
      old.now.hour != now.hour ||
      old.scheme != scheme;
}
