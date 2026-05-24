/// Layout constants tuned for a 7-10" head unit at ~160 dpi.
abstract final class Layout {
  static const double sidebarWidth = 72.0;
  static const double cardRadius = 20.0;
  static const double squircleRadius = 24.0;

  // App grid defaults — overridable via LauncherSettings at runtime
  static const double appIconSizeDefault = 96.0;
  static const double appGridSpacing = 14.0;
  static const double appGridPaddingH = 16.0;
  static const double appGridPaddingV = 12.0;
  static const int appGridColumnsDefault = 5;

  static const double cardPadding = 16.0;
}
