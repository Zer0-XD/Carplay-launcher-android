import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/speed_service.dart';
import '../../providers/settings_provider.dart';
import 'base_card.dart';

class SpeedCard extends StatelessWidget {
  const SpeedCard({super.key, this.isEditing = false, this.onLongPress, this.isLarge = false});

  final bool isEditing;
  final VoidCallback? onLongPress;
  final bool isLarge;

  static const _green = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final speedLimit = context.select<SettingsProvider, int>(
      (sp) => sp.settings.speedLimitKmh,
    );
    return BaseCard(
      isEditing: isEditing,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      accentColor: _green,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = (constraints.smallest.shortestSide / 200.0).clamp(0.5, 2.0);
          final wide = constraints.maxWidth > constraints.maxHeight * 1.2;
          return StreamBuilder<double>(
            stream: SpeedService.instance.stream,
            initialData: 0,
            builder: (context, snap) {
              final kmh = snap.data ?? 0;
              return wide
                  ? _ArcSpeedometer(kmh: kmh, speedLimit: speedLimit, s: s)
                  : _DigitalSpeedometer(kmh: kmh, speedLimit: speedLimit, s: s);
            },
          );
        },
      ),
    );
  }
}

// ── Arc speedometer (wide layout) ─────────────────────────────────────────────

class _ArcSpeedometer extends StatefulWidget {
  const _ArcSpeedometer({required this.kmh, required this.speedLimit, required this.s});
  final double kmh;
  final int speedLimit;
  final double s;

  @override
  State<_ArcSpeedometer> createState() => _ArcSpeedometerState();
}

class _ArcSpeedometerState extends State<_ArcSpeedometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _anim = Tween<double>(begin: 0, end: widget.kmh)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ArcSpeedometer old) {
    super.didUpdateWidget(old);
    if (old.kmh != widget.kmh) {
      _anim = Tween<double>(begin: _anim.value, end: widget.kmh)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final over = widget.kmh > widget.speedLimit;
    final ratio = (widget.kmh / widget.speedLimit).clamp(0.0, 1.5);
    final needleColor = over
        ? const Color(0xFFEF4444)
        : ratio > 0.85
            ? Color.lerp(Colors.white, const Color(0xFFF59E0B), (ratio - 0.85) / 0.15)!
            : Colors.white;
    final arcColor = over ? const Color(0xFFEF4444)
        : ratio > 0.85 ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final speed = _anim.value;
        final fraction = (speed / 220).clamp(0.0, 1.0);
        final limitFrac = (widget.speedLimit / 220).clamp(0.0, 1.0);

        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 14 * s, 18 * s, 10 * s),
          child: Column(
            children: [
              Row(
                children: [
                  Text('SPEED',
                    style: TextStyle(
                      fontSize: 9 * s, fontWeight: FontWeight.w700,
                      letterSpacing: 2.5, color: scheme.onSurface.withAlpha(80),
                    )),
                  const Spacer(),
                  _LimitBadge(limit: widget.speedLimit, over: over, s: s),
                ],
              ),
              SizedBox(height: 6 * s),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.7,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _ArcPainter(
                          fraction: fraction,
                          limitFrac: limitFrac,
                          arcColor: arcColor,
                          over: over,
                          trackColor: scheme.surfaceContainerHigh,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 12 * s),
                              Text(
                                speed.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 68 * s,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -3,
                                  height: 1.0,
                                  color: needleColor,
                                ),
                              ),
                              Text(
                                'km/h',
                                style: TextStyle(
                                  fontSize: 11 * s, fontWeight: FontWeight.w500,
                                  letterSpacing: 2, color: scheme.onSurface.withAlpha(80),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * s),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final v in [0, 55, 110, 165, 220])
                      Text('$v',
                        style: TextStyle(
                          fontSize: 8 * s, fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withAlpha(55),
                        )),
                  ],
                ),
              ),
              // Over-limit warning
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: over
                    ? Padding(
                        padding: EdgeInsets.only(top: 8 * s),
                        child: _OverBanner(
                            excess: (widget.kmh - widget.speedLimit).round(), s: s),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Digital speedometer (tall / compact) ──────────────────────────────────────

class _DigitalSpeedometer extends StatefulWidget {
  const _DigitalSpeedometer({required this.kmh, required this.speedLimit, required this.s});
  final double kmh;
  final int speedLimit;
  final double s;

  @override
  State<_DigitalSpeedometer> createState() => _DigitalSpeedometerState();
}

class _DigitalSpeedometerState extends State<_DigitalSpeedometer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _anim = Tween<double>(begin: 0, end: widget.kmh)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_DigitalSpeedometer old) {
    super.didUpdateWidget(old);
    if (old.kmh != widget.kmh) {
      _anim = Tween<double>(begin: _anim.value, end: widget.kmh)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
      _ctrl..reset()..forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final over = widget.kmh > widget.speedLimit;
    final fraction = (widget.kmh / 220).clamp(0.0, 1.0);
    final limitFrac = (widget.speedLimit / 220).clamp(0.0, 1.0);
    final ratio = (widget.kmh / widget.speedLimit).clamp(0.0, 1.5);
    final speedColor = over
        ? const Color(0xFFEF4444)
        : ratio > 0.85
            ? Color.lerp(Colors.white, const Color(0xFFF59E0B), (ratio - 0.85) / 0.15)!
            : Colors.white;

    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
        child: Column(
          children: [
            Row(
              children: [
                Text('SPEED',
                  style: TextStyle(
                    fontSize: 9 * s, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: scheme.onSurface.withAlpha(80),
                  )),
                const Spacer(),
                _LimitBadge(limit: widget.speedLimit, over: over, s: s),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _anim.value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 80 * s,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -4,
                    height: 1.0,
                    color: speedColor,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 10 * s, left: 6 * s),
                  child: Text('km/h',
                    style: TextStyle(
                      fontSize: 12 * s, fontWeight: FontWeight.w400,
                      letterSpacing: 0.5, color: scheme.onSurface.withAlpha(100),
                    )),
                ),
              ],
            ),
            SizedBox(height: 12 * s),
            _SegmentBar(fraction: fraction, limitFrac: limitFrac, over: over,
                trackColor: scheme.surfaceContainerHigh),
            SizedBox(height: 5 * s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final v in [0, 55, 110, 165, 220])
                  Text('$v',
                    style: TextStyle(
                      fontSize: 8 * s, fontWeight: FontWeight.w500,
                      color: scheme.onSurface.withAlpha(55),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segment bar ───────────────────────────────────────────────────────────────

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.fraction, required this.limitFrac, required this.over, required this.trackColor});
  final double fraction;
  final double limitFrac;
  final bool over;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: CustomPaint(
        painter: _SegPainter(fraction: fraction, limitFrac: limitFrac, over: over, trackColor: trackColor),
        size: Size.infinite,
      ),
    );
  }
}

class _SegPainter extends CustomPainter {
  const _SegPainter({required this.fraction, required this.limitFrac, required this.over, required this.trackColor});
  final double fraction;
  final double limitFrac;
  final bool over;
  final Color trackColor;

  static const _n = 40;
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final segW = (size.width - _gap * (_n - 1)) / _n;
    final limitSeg = (limitFrac * _n).round();

    for (var i = 0; i < _n; i++) {
      final x = i * (segW + _gap);
      final filled = (i + 1) / _n <= fraction;
      final isOver = i >= limitSeg;

      Color c;
      if (!filled) {
        c = trackColor;
      } else if (isOver) {
        final t = ((i - limitSeg) / (_n - limitSeg)).clamp(0.0, 1.0);
        c = Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), t)!;
      } else {
        c = const Color(0xFF10B981);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, segW, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(_SegPainter old) =>
      old.fraction != fraction || old.limitFrac != limitFrac || old.over != over || old.trackColor != trackColor;
}

// ── Arc gauge painter ─────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.fraction,
    required this.limitFrac,
    required this.arcColor,
    required this.over,
    required this.trackColor,
  });
  final double fraction;
  final double limitFrac;
  final Color arcColor;
  final bool over;
  final Color trackColor;

  static const _start = 160.0 * (math.pi / 180);
  static const _sweep = 220.0 * (math.pi / 180);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.78;
    final r = size.width * 0.46;
    final tw = size.height * 0.055;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, _start, _sweep, false,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = tw
          ..strokeCap = StrokeCap.round);

    // Limit marker
    final lAngle = _start + _sweep * limitFrac;
    final markerPaint = Paint()
      ..color = const Color(0xFFEF4444).withAlpha(220)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + (r - tw * 0.9) * math.cos(lAngle), cy + (r - tw * 0.9) * math.sin(lAngle)),
      Offset(cx + (r + tw * 0.4) * math.cos(lAngle), cy + (r + tw * 0.4) * math.sin(lAngle)),
      markerPaint,
    );

    // Filled arc
    if (fraction > 0) {
      final sa = _sweep * fraction;
      canvas.drawArc(rect, _start, sa, false,
          Paint()
            ..color = arcColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = tw
            ..strokeCap = StrokeCap.round);

      // Glow tip
      final tipA = _start + sa;
      canvas.drawCircle(
        Offset(cx + r * math.cos(tipA), cy + r * math.sin(tipA)),
        tw * 0.6,
        Paint()
          ..color = arcColor.withAlpha(140)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Minor ticks — use arc color at low alpha so they're visible on any surface
    for (var i = 0; i <= 44; i++) {
      final t = i / 44;
      final a = _start + _sweep * t;
      final major = i % 11 == 0;
      final inner = r - tw * 1.4 - (major ? 6 : 3);
      final outer = r - tw * 1.4;
      canvas.drawLine(
        Offset(cx + inner * math.cos(a), cy + inner * math.sin(a)),
        Offset(cx + outer * math.cos(a), cy + outer * math.sin(a)),
        Paint()
          ..color = arcColor.withAlpha(major ? 120 : 45)
          ..strokeWidth = major ? 1.5 : 0.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.fraction != fraction || old.limitFrac != limitFrac ||
      old.arcColor != arcColor || old.over != over || old.trackColor != trackColor;
}

// ── Over-limit banner ─────────────────────────────────────────────────────────

class _OverBanner extends StatelessWidget {
  const _OverBanner({required this.excess, required this.s});
  final int excess;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withAlpha(100), width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFEF4444), size: 12 * s),
          SizedBox(width: 6 * s),
          Text(
            'Over limit by $excess km/h',
            style: TextStyle(
              fontSize: 10 * s, color: const Color(0xFFEF4444),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Speed limit badge ─────────────────────────────────────────────────────────

class _LimitBadge extends StatelessWidget {
  const _LimitBadge({required this.limit, required this.over, required this.s});
  final int limit;
  final bool over;
  final double s;

  @override
  Widget build(BuildContext context) {
    final color = over ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: 9 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, size: 10 * s, color: color.withAlpha(180)),
          SizedBox(width: 4 * s),
          Text(
            '$limit',
            style: TextStyle(
              fontSize: 11 * s, fontWeight: FontWeight.w700, color: color.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }
}
