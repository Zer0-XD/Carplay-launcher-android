import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'base_card.dart';

class MapCard extends StatelessWidget {
  const MapCard({super.key, this.isEditing = false, this.onLongPress});

  final bool isEditing;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BaseCard(
      isEditing: isEditing,
      onLongPress: onLongPress,
      padding: EdgeInsets.zero,
      accentColor: const Color(0xFF0A84FF),
      surfaceColor: isDark ? const Color(0xFF0D1520) : const Color(0xFFE4EDE4),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(0)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _MapPainter(isDark: isDark)),

            // Subtle vignette frame
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(isDark ? 80 : 40),
                    ],
                  ),
                ),
              ),
            ),

            // Location pin
            const Positioned(
              left: 0, right: 0, top: 0, bottom: 20,
              child: Center(child: _LocationPin()),
            ),

            // Bottom info bar
            Positioned(
              left: 10, right: 10, bottom: 10,
              child: _InfoBar(isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info bar ──────────────────────────────────────────────────────────────────

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xD0101825) : Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF1C2840) : const Color(0xFFCCDDCC),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, size: 12, color: Color(0xFF0A84FF)),
          const SizedBox(width: 6),
          Text(
            'Maps',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withAlpha(200) : Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF34D399), shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'GPS Active',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white.withAlpha(120) : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map painter ───────────────────────────────────────────────────────────────

final List<({Rect block, List<Rect> buildings})> _cachedBlocks = () {
  final blockFractions = [
    Rect.fromLTWH(0.38, 0.08, 0.16, 0.18),
    Rect.fromLTWH(0.58, 0.08, 0.12, 0.18),
    Rect.fromLTWH(0.38, 0.34, 0.16, 0.20),
    Rect.fromLTWH(0.58, 0.34, 0.12, 0.20),
    Rect.fromLTWH(0.74, 0.34, 0.18, 0.20),
    Rect.fromLTWH(0.05, 0.52, 0.20, 0.22),
    Rect.fromLTWH(0.29, 0.62, 0.14, 0.16),
    Rect.fromLTWH(0.48, 0.62, 0.18, 0.16),
    Rect.fromLTWH(0.70, 0.62, 0.16, 0.16),
  ];
  final rng = math.Random(42);
  return blockFractions.map((b) {
    final cols = 2 + rng.nextInt(2);
    final rows = 1 + rng.nextInt(2);
    final bwF = b.width / (cols * 1.6);
    final bhF = b.height / (rows * 1.6);
    final buildings = <Rect>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final bxF = b.left + c * (b.width / cols) + b.width / cols * 0.2;
        final byF = b.top + r * (b.height / rows) + b.height / rows * 0.2;
        buildings.add(Rect.fromLTWH(bxF, byF, bwF, bhF));
      }
    }
    return (block: b, buildings: buildings);
  }).toList();
}();

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = isDark ? const Color(0xFF111E2E) : const Color(0xFFE8F0E8);
    final road = isDark ? const Color(0xFF1A2E46) : const Color(0xFFCCDACC);
    final mainRoad = isDark ? const Color(0xFF224060) : const Color(0xFFB8CEB8);
    final block = isDark ? const Color(0xFF162232) : const Color(0xFFD8E8D8);
    final park = isDark ? const Color(0xFF112820) : const Color(0xFFBED8BE);
    final water = isDark ? const Color(0xFF0E1E30) : const Color(0xFFAEC8DC);
    final building = isDark ? const Color(0xFF1C2E42) : const Color(0xFFC4D0C4);

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bg);

    // Park
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.05, h * 0.1, w * 0.28, h * 0.35),
        const Radius.circular(6),
      ),
      Paint()..color = park,
    );
    // Park paths
    final pathPaint = Paint()
      ..color = isDark ? const Color(0xFF183020) : const Color(0xFFAAD0AA)
      ..strokeWidth = h * 0.012
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.12, h * 0.15), Offset(w * 0.28, h * 0.40), pathPaint);
    canvas.drawLine(Offset(w * 0.20, h * 0.12), Offset(w * 0.20, h * 0.42), pathPaint);

    // Water
    final waterPath = Path()
      ..moveTo(w * 0.72, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.28)
      ..quadraticBezierTo(w * 0.85, h * 0.22, w * 0.72, h * 0.12)
      ..close();
    canvas.drawPath(waterPath, Paint()..color = water);

    // City blocks
    for (final e in _cachedBlocks) {
      final b = e.block;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b.left * w, b.top * h, b.width * w, b.height * h),
          const Radius.circular(3),
        ),
        Paint()..color = block,
      );
    }

    // Buildings
    for (final e in _cachedBlocks) {
      for (final bf in e.buildings) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bf.left * w, bf.top * h, bf.width * w, bf.height * h),
            const Radius.circular(2),
          ),
          Paint()..color = building,
        );
      }
    }

    // Side roads
    final sideP = Paint()
      ..color = road
      ..strokeWidth = h * 0.025
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final pts in [
      [Offset(0, h * 0.30), Offset(w, h * 0.30)],
      [Offset(0, h * 0.58), Offset(w, h * 0.58)],
      [Offset(w * 0.36, 0), Offset(w * 0.36, h)],
      [Offset(w * 0.56, 0), Offset(w * 0.56, h)],
      [Offset(w * 0.72, 0), Offset(w * 0.72, h)],
      [Offset(w * 0.56, h * 0.0), Offset(w * 0.85, h * 0.50)],
    ]) {
      canvas.drawLine(pts[0], pts[1], sideP);
    }

    // Main roads
    final mainP = Paint()
      ..color = mainRoad
      ..strokeWidth = h * 0.048
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final pts in [
      [Offset(0, h * 0.50), Offset(w, h * 0.50)],
      [Offset(w * 0.26, 0), Offset(w * 0.26, h)],
    ]) {
      canvas.drawLine(pts[0], pts[1], mainP);
    }

    // Dashes on main road
    final dashP = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(25)
      ..strokeWidth = 1.2;
    var x = 0.0;
    while (x < w) {
      canvas.drawLine(Offset(x, h * 0.50), Offset(x + 10, h * 0.50), dashP);
      x += 24;
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.isDark != isDark;
}

// ── Location pin ──────────────────────────────────────────────────────────────

class _LocationPin extends StatefulWidget {
  const _LocationPin();

  @override
  State<_LocationPin> createState() => _LocationPinState();
}

class _LocationPinState extends State<_LocationPin>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _pulse = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Transform.scale(
                scale: 1.0 + _pulse.value * 1.4,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0A84FF)
                          .withAlpha(((1.0 - _pulse.value) * 100).round()),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            // Solid pin
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF0A84FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A84FF).withAlpha(140),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 17),
            ),
          ],
        ),
        // Tail
        CustomPaint(size: const Size(11, 7), painter: _TailPainter()),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      Paint()..color = const Color(0xFF0A84FF),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
