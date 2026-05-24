import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A continuous superellipse (squircle) shape that matches Apple's icon
/// corner style. The exponent [n] controls smoothness: 4 is close to the
/// iOS icon, 5 is slightly sharper.
class SquircleBorder extends ShapeBorder {
  const SquircleBorder({this.radius = 22.0, this.n = 4.0});

  final double radius;
  final double n;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) =>
      SquircleBorder(radius: radius * t, n: n);

  Path _path(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    final cx = rect.left + w / 2;
    final cy = rect.top + h / 2;
    final rx = math.min(radius, w / 2);
    final ry = math.min(radius, h / 2);

    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final t = (i / steps) * 2 * math.pi;
      final cosT = math.cos(t);
      final sinT = math.sin(t);
      final x =
          cx + rx * math.pow(cosT.abs(), 2 / n) * (cosT >= 0 ? 1.0 : -1.0);
      final y =
          cy + ry * math.pow(sinT.abs(), 2 / n) * (sinT >= 0 ? 1.0 : -1.0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
