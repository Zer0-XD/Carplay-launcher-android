import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fullscreen startup sweep — plays once on screen-on / app resume.
/// The needle arcs from 0 → max, overshoots slightly, then returns to 0,
/// exactly like a modern car instrument cluster self-test (Civic, Accord, etc).
///
/// Call [StartupOverlay.show] from the shell; the overlay removes itself.
class StartupOverlay extends StatefulWidget {
  const StartupOverlay({super.key, required this.onComplete});

  final VoidCallback onComplete;

  static OverlayEntry show(BuildContext context, {required VoidCallback onComplete}) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => StartupOverlay(
        onComplete: () {
          entry.remove();
          onComplete();
        },
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<StartupOverlay> createState() => _StartupOverlayState();
}

class _StartupOverlayState extends State<StartupOverlay>
    with TickerProviderStateMixin {
  // ── Timeline ──────────────────────────────────────────────────────────────
  // Phase 1 (0–900 ms):  fade-in, needle sweeps to max (with overshoot)
  // Phase 2 (900–1600 ms): hold at max briefly
  // Phase 3 (1600–2200 ms): needle returns to 0
  // Phase 4 (2200–2900 ms): fade out, done

  late final AnimationController _sweepCtrl;   // needle position
  late final AnimationController _fadeCtrl;    // whole overlay opacity
  late final AnimationController _glowCtrl;    // ambient glow pulse while at max

  late final Animation<double> _sweepAnim;
  late final Animation<double> _returnAnim;
  late final Animation<double> _fadeIn;
  late final Animation<double> _fadeOut;
  late final Animation<double> _glowAnim;

  // Also drive the rev counter (RPM tach) for the dual-gauge look
  late final Animation<double> _rpmAnim;
  late final Animation<double> _rpmReturnAnim;

  bool _returning = false;

  @override
  void initState() {
    super.initState();

    // ── Sweep controller ─────────────────────────────────────────────────────
    _sweepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Overshoot: go to 1.08 then settle at 1.0 (elasticOut feel)
    _sweepAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_sweepCtrl);

    _rpmAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.82)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 75,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.82, end: 0.74)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_sweepCtrl);

    // Return sweep (after hold)
    _returnAnim = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInCubic),
    );
    _rpmReturnAnim = Tween(begin: 0.74, end: 0.0).animate(
      CurvedAnimation(parent: _sweepCtrl, curve: Curves.easeInCubic),
    );

    // ── Fade controller ───────────────────────────────────────────────────────
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeOut = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn),
    );

    // ── Glow pulse while at max ───────────────────────────────────────────────
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _glowAnim = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Fade in overlay
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 120));

    // Sweep needles to max
    await _sweepCtrl.forward();

    // Hold + glow pulse
    _glowCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 700));
    _glowCtrl.stop();

    // Return needles to zero
    setState(() => _returning = true);
    _sweepCtrl.reset();
    await _sweepCtrl.forward(from: 0);

    // Fade out
    await Future.delayed(const Duration(milliseconds: 80));
    _fadeCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 420));

    widget.onComplete();
  }

  @override
  void dispose() {
    _sweepCtrl.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sweepCtrl, _fadeCtrl, _glowCtrl]),
        builder: (_, __) {
          final opacity = _returning ? _fadeOut.value : _fadeIn.value;
          final speedFrac = _returning
              ? _returnAnim.value.clamp(0.0, 1.0)
              : _sweepAnim.value.clamp(0.0, 1.0);
          final rpmFrac = _returning
              ? _rpmReturnAnim.value.clamp(0.0, 1.0)
              : _rpmAnim.value.clamp(0.0, 1.0);

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: _ClusterScreen(
              speedFraction: speedFrac,
              rpmFraction: rpmFrac,
              glowIntensity: _glowAnim.value,
              isAtMax: _returning == false && _sweepCtrl.isCompleted,
            ),
          );
        },
      ),
    );
  }
}

// ── Instrument cluster layout ─────────────────────────────────────────────────

class _ClusterScreen extends StatelessWidget {
  const _ClusterScreen({
    required this.speedFraction,
    required this.rpmFraction,
    required this.glowIntensity,
    required this.isAtMax,
  });

  final double speedFraction;
  final double rpmFraction;
  final double glowIntensity;
  final bool isAtMax;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gaugeRadius = (size.height * 0.38).clamp(140.0, 220.0);

    return Stack(
      children: [
        // ── Deep space background ──────────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFF0A0E1A),
                  const Color(0xFF060810),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),

        // ── Ambient centre glow (intensifies when needles are at max) ──────
        if (isAtMax)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.7,
                    colors: [
                      Color.lerp(
                        Colors.transparent,
                        const Color(0xFF10B981).withAlpha(30),
                        glowIntensity,
                      )!,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Two gauges side by side ────────────────────────────────────────
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // RPM Tachometer
              _GaugeWidget(
                radius: gaugeRadius,
                fraction: rpmFraction,
                maxLabel: '8',
                unit: 'RPM ×1000',
                arcColor: const Color(0xFFFF6B35),
                tickColor: const Color(0xFFFF6B35),
                isReversed: true,
                glowIntensity: isAtMax ? glowIntensity : 0,
                labels: const ['0', '1', '2', '3', '4', '5', '6', '7', '8'],
              ),

              SizedBox(width: gaugeRadius * 0.18),

              // Centre console: brand mark + speed readout
              _CentrePanel(
                speedFraction: speedFraction,
                glowIntensity: isAtMax ? glowIntensity : 0,
                gaugeRadius: gaugeRadius,
              ),

              SizedBox(width: gaugeRadius * 0.18),

              // Speedometer
              _GaugeWidget(
                radius: gaugeRadius,
                fraction: speedFraction,
                maxLabel: '220',
                unit: 'km/h',
                arcColor: const Color(0xFF10B981),
                tickColor: const Color(0xFF10B981),
                isReversed: false,
                glowIntensity: isAtMax ? glowIntensity : 0,
                labels: const ['0', '40', '80', '120', '160', '200', '220'],
              ),
            ],
          ),
        ),

        // ── Bottom status bar ──────────────────────────────────────────────
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: _StatusBar(speedFraction: speedFraction),
        ),
      ],
    );
  }
}

// ── Single gauge (tach or speedo) ─────────────────────────────────────────────

class _GaugeWidget extends StatelessWidget {
  const _GaugeWidget({
    required this.radius,
    required this.fraction,
    required this.maxLabel,
    required this.unit,
    required this.arcColor,
    required this.tickColor,
    required this.isReversed,
    required this.glowIntensity,
    required this.labels,
  });

  final double radius;
  final double fraction;
  final String maxLabel;
  final String unit;
  final Color arcColor;
  final Color tickColor;
  final bool isReversed;
  final double glowIntensity;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final sz = radius * 2;
    return SizedBox(
      width: sz,
      height: sz,
      child: CustomPaint(
        painter: _GaugePainter(
          fraction: fraction,
          arcColor: arcColor,
          tickColor: tickColor,
          isReversed: isReversed,
          glowIntensity: glowIntensity,
          labels: labels,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: radius * 0.22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: radius * 0.115,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: Colors.white.withAlpha(90),
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

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fraction,
    required this.arcColor,
    required this.tickColor,
    required this.isReversed,
    required this.glowIntensity,
    required this.labels,
  });

  final double fraction;
  final Color arcColor;
  final Color tickColor;
  final bool isReversed;
  final double glowIntensity;
  final List<String> labels;

  // Arc: 225° sweep, starting bottom-left (for speedo) or bottom-right (for tach)
  static const _sweepDeg = 225.0;

  double get _startAngle {
    final deg = isReversed ? (180 - _sweepDeg / 2) : (_sweepDeg / 2 + 90);
    return deg * (math.pi / 180);
  }

  double get _sweepTotal => _sweepDeg * (math.pi / 180);
  double get _direction => isReversed ? -1.0 : 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;
    final trackW = size.width * 0.055;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // ── Track ──────────────────────────────────────────────────────────────
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepTotal * _direction,
      false,
      Paint()
        ..color = Colors.white.withAlpha(16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackW
        ..strokeCap = StrokeCap.round,
    );

    // ── Filled arc with gradient ───────────────────────────────────────────
    if (fraction > 0.005) {
      final sweep = _sweepTotal * fraction * _direction;
      final shader = SweepGradient(
        center: Alignment.center,
        startAngle: _startAngle,
        endAngle: _startAngle + sweep,
        colors: [
          arcColor.withAlpha(160),
          arcColor,
        ],
      ).createShader(rect);

      canvas.drawArc(
        rect,
        _startAngle,
        sweep,
        false,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = trackW
          ..strokeCap = StrokeCap.round,
      );

      // Glowing tip
      final tipAngle = _startAngle + sweep;
      final tipX = cx + r * math.cos(tipAngle);
      final tipY = cy + r * math.sin(tipAngle);
      if (glowIntensity > 0) {
        canvas.drawCircle(
          Offset(tipX, tipY),
          trackW * 0.7,
          Paint()
            ..color = arcColor.withAlpha((180 * glowIntensity).round())
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity),
        );
      }
      canvas.drawCircle(
        Offset(tipX, tipY),
        trackW * 0.38,
        Paint()..color = Colors.white.withAlpha(220),
      );
    }

    // ── Needle ─────────────────────────────────────────────────────────────
    _drawNeedle(canvas, cx, cy, r, trackW);

    // ── Tick marks ────────────────────────────────────────────────────────
    _drawTicks(canvas, cx, cy, r, trackW);

    // ── Scale labels ──────────────────────────────────────────────────────
    _drawLabels(canvas, size, cx, cy, r, trackW);

    // ── Centre hub ────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      trackW * 0.65,
      Paint()
        ..color = const Color(0xFF1A1A2E)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      trackW * 0.35,
      Paint()..color = arcColor,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      trackW * 0.65,
      Paint()
        ..color = Colors.white.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawNeedle(Canvas canvas, double cx, double cy, double r, double trackW) {
    final angle = _startAngle + _sweepTotal * fraction * _direction;
    final needleLen = r * 0.85;
    final needleBaseLen = r * 0.14;

    final tipX = cx + needleLen * math.cos(angle);
    final tipY = cy + needleLen * math.sin(angle);
    final baseX = cx - needleBaseLen * math.cos(angle);
    final baseY = cy - needleBaseLen * math.sin(angle);

    // Shadow
    canvas.drawLine(
      Offset(baseX + 2, baseY + 2),
      Offset(tipX + 2, tipY + 2),
      Paint()
        ..color = Colors.black.withAlpha(120)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Needle body
    final needlePath = Path();
    final perpAngle = angle + math.pi / 2;
    final halfW = 3.0;
    needlePath.moveTo(
      baseX + halfW * math.cos(perpAngle),
      baseY + halfW * math.sin(perpAngle),
    );
    needlePath.lineTo(tipX, tipY);
    needlePath.lineTo(
      baseX - halfW * math.cos(perpAngle),
      baseY - halfW * math.sin(perpAngle),
    );
    needlePath.close();

    canvas.drawPath(
      needlePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Red tip stripe
    final redLen = needleLen * 0.22;
    final redStart = cx + (needleLen - redLen) * math.cos(angle);
    final redStartY = cy + (needleLen - redLen) * math.sin(angle);
    canvas.drawLine(
      Offset(redStart, redStartY),
      Offset(tipX, tipY),
      Paint()
        ..color = arcColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawTicks(Canvas canvas, double cx, double cy, double r, double trackW) {
    const totalTicks = 36;
    final majorPaint = Paint()
      ..color = Colors.white.withAlpha(160)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i <= totalTicks; i++) {
      final t = i / totalTicks;
      final angle = _startAngle + _sweepTotal * t * _direction;
      final isMajor = i % 6 == 0;
      final innerR = r - trackW * 1.6 - (isMajor ? 10 : 5);
      final outerR = r - trackW * 1.6;
      canvas.drawLine(
        Offset(cx + innerR * math.cos(angle), cy + innerR * math.sin(angle)),
        Offset(cx + outerR * math.cos(angle), cy + outerR * math.sin(angle)),
        isMajor ? majorPaint : minorPaint,
      );
    }
  }

  void _drawLabels(Canvas canvas, Size size, double cx, double cy, double r, double trackW) {
    final labelR = r - trackW * 2.8;
    final count = labels.length;
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final angle = _startAngle + _sweepTotal * t * _direction;
      final lx = cx + labelR * math.cos(angle);
      final ly = cy + labelR * math.sin(angle);

      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: size.width * 0.07,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(180),
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(lx - tp.width / 2, ly - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.glowIntensity != glowIntensity;
}

// ── Centre panel (brand + digital readout) ────────────────────────────────────

class _CentrePanel extends StatelessWidget {
  const _CentrePanel({
    required this.speedFraction,
    required this.glowIntensity,
    required this.gaugeRadius,
  });

  final double speedFraction;
  final double glowIntensity;
  final double gaugeRadius;

  @override
  Widget build(BuildContext context) {
    final speedKmh = (speedFraction * 220).clamp(0.0, 220.0);
    final panelW = gaugeRadius * 0.9;

    return SizedBox(
      width: panelW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand wordmark
          Text(
            'CARPLAY',
            style: TextStyle(
              fontSize: gaugeRadius * 0.14,
              fontWeight: FontWeight.w900,
              letterSpacing: gaugeRadius * 0.055,
              color: Colors.white.withAlpha(220),
            ),
          ),
          Text(
            'LAUNCHER',
            style: TextStyle(
              fontSize: gaugeRadius * 0.07,
              fontWeight: FontWeight.w300,
              letterSpacing: gaugeRadius * 0.05,
              color: Colors.white.withAlpha(80),
            ),
          ),

          SizedBox(height: gaugeRadius * 0.15),

          // Digital speed readout
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: gaugeRadius * 0.12,
              vertical: gaugeRadius * 0.08,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(30),
                width: 0.8,
              ),
              boxShadow: glowIntensity > 0
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withAlpha((40 * glowIntensity).round()),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              speedKmh.toStringAsFixed(0).padLeft(3, ' '),
              style: TextStyle(
                fontSize: gaugeRadius * 0.38,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                height: 1.0,
                color: const Color(0xFF10B981),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          SizedBox(height: gaugeRadius * 0.06),

          Text(
            'km/h',
            style: TextStyle(
              fontSize: gaugeRadius * 0.09,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              color: Colors.white.withAlpha(60),
            ),
          ),

          SizedBox(height: gaugeRadius * 0.18),

          // System check indicators
          _CheckRow(gaugeRadius: gaugeRadius),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.gaugeRadius});
  final double gaugeRadius;

  @override
  Widget build(BuildContext context) {
    final iconSz = gaugeRadius * 0.13;
    const items = [
      (Icons.wifi_rounded, Color(0xFF10B981), 'NET'),
      (Icons.bluetooth_rounded, Color(0xFF0A84FF), 'BT'),
      (Icons.gps_fixed_rounded, Color(0xFFFBBF24), 'GPS'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        final (icon, color, label) = item;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gaugeRadius * 0.04),
          child: Column(
            children: [
              Icon(icon, size: iconSz, color: color),
              SizedBox(height: gaugeRadius * 0.025),
              Text(
                label,
                style: TextStyle(
                  fontSize: gaugeRadius * 0.065,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: color.withAlpha(160),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Bottom status bar ─────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.speedFraction});
  final double speedFraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thin progress line at very bottom
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: speedFraction,
              backgroundColor: Colors.white.withAlpha(14),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'SYSTEM CHECK',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            color: Colors.white.withAlpha(50),
          ),
        ),
      ],
    );
  }
}
