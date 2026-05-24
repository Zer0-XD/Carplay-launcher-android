import 'dart:ui' show FlutterView;

/// Headunit-aware UI scaling utility.
///
/// Most Android headunits report devicePixelRatio = 1.0 regardless of physical
/// resolution, which makes Flutter lay out the UI at native pixel size — on a
/// 1024×600 screen that means the logical canvas is also 1024×600 dp, so
/// everything looks correctly sized WITHOUT any extra scaling.
///
/// The real problem is that the UI was originally designed for a ~480 dp tall
/// phone (~800×480 px @ 1.0 dpr), so on a 600-dp-tall headunit there is too
/// much empty space and text/icons look proportionally small.
///
/// Solution: compare the actual logical height to the design baseline and
/// produce a scale factor that stretches the UI to fill the larger canvas.
/// We only scale up — never down — and cap at 1.6× to stay sane.

/// Design baseline the UI was built for (logical pixels, landscape).
const double _kBaselineHeight = 480.0;

/// Maximum auto scale. Beyond this things look blown-out on very large screens.
const double _kMaxAutoScale = 1.5;

/// Returns a layout scale multiplier for the current [view].
///
/// Returns 1.0 when the screen exactly matches the baseline.
/// Returns > 1.0 on larger screens (e.g. 1024×600 → ~1.25).
double autoUiScale(FlutterView view) {
  final dpr = view.devicePixelRatio;
  final logicalH = view.physicalSize.shortestSide / dpr;
  final scale = logicalH / _kBaselineHeight;
  return scale.clamp(1.0, _kMaxAutoScale);
}

/// Resolves the effective scale:
/// - [stored] == 0.0  → use auto detection
/// - anything else    → use [stored] directly (user override from settings)
double resolveUiScale(double stored, FlutterView view) {
  if (stored == 0.0) return autoUiScale(view);
  return stored.clamp(0.75, 1.6);
}
