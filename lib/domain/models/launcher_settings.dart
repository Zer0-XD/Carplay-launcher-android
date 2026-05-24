import 'dashboard_tile.dart';

enum BackgroundStyle {
  // Gradient presets
  darkGradient,
  blueGradient,
  purpleGradient,
  solidDark,
  solidLight,
  // Photo wallpapers
  photo1,
  photo2,
  photo3,
  photo4,
  photo5,
  photo6,
}

enum AccentColor { blue, green, orange, red, purple, teal }

class LauncherSettings {
  const LauncherSettings({
    this.isDarkMode = true,
    this.sidebarOnLeft = true,
    this.dashboardTiles = const [],
    this.dashboardPages = const [],
    this.currentDashboardPage = 0,
    this.pinnedPackages = const [],
    this.sidebarDockPackages = const [],
    this.recentAppPackage,
    this.backgroundStyle = BackgroundStyle.photo1,
    this.accentColor = AccentColor.blue,
    this.appIconSize = 96.0,
    this.showAppLabels = true,
    this.gridColumns = 5,
    this.speedLimitKmh = 80,
    this.uiScale = 0.0,
  });

  final bool isDarkMode;
  final bool sidebarOnLeft;
  /// Legacy single-page tiles — kept for migration; prefer [dashboardPages].
  final List<DashboardTile> dashboardTiles;
  /// Multi-page dashboard. Each inner list is one page of 3 tiles.
  final List<List<DashboardTile>> dashboardPages;
  final int currentDashboardPage;
  final List<String> pinnedPackages;
  /// Up to 2 drag-pinned apps in the sidebar
  final List<String> sidebarDockPackages;
  /// The single most-recently launched app shown in the sidebar
  final String? recentAppPackage;
  final BackgroundStyle backgroundStyle;
  final AccentColor accentColor;
  final double appIconSize;
  final bool showAppLabels;
  final int gridColumns;
  final int speedLimitKmh;
  /// 0.0 = auto-detect from screen size; otherwise a fixed multiplier (e.g. 1.15).
  final double uiScale;

  /// Tiles for the currently-active dashboard page (never empty).
  List<DashboardTile> get activeTiles {
    if (dashboardPages.isNotEmpty) {
      final idx = currentDashboardPage.clamp(0, dashboardPages.length - 1);
      return dashboardPages[idx];
    }
    // Fall back to legacy single-page list
    return dashboardTiles.isNotEmpty ? dashboardTiles : defaultTiles();
  }

  factory LauncherSettings.fromPrefs({
    bool? isDarkMode,
    bool? sidebarOnLeft,
    List<DashboardTile>? dashboardTiles,
    List<List<DashboardTile>>? dashboardPages,
    int? currentDashboardPage,
    List<String>? pinnedPackages,
    List<String>? sidebarDockPackages,
    String? recentAppPackage,
    String? backgroundStyleName,
    String? accentColorName,
    double? appIconSize,
    bool? showAppLabels,
    int? gridColumns,
    int? speedLimitKmh,
    double? uiScale,
  }) {
    final legacy = dashboardTiles ?? defaultTiles();
    // If no multi-page data saved yet, seed from legacy tiles
    final pages = (dashboardPages != null && dashboardPages.isNotEmpty)
        ? dashboardPages
        : [legacy];
    return LauncherSettings(
      isDarkMode: isDarkMode ?? true,
      sidebarOnLeft: sidebarOnLeft ?? true,
      dashboardTiles: legacy,
      dashboardPages: pages,
      currentDashboardPage: (currentDashboardPage ?? 0).clamp(0, pages.length - 1),
      pinnedPackages: pinnedPackages ?? const [],
      sidebarDockPackages: (sidebarDockPackages ?? const []).take(2).toList(),
      recentAppPackage: recentAppPackage,
      backgroundStyle: _safeEnum(
          BackgroundStyle.values, backgroundStyleName, BackgroundStyle.photo1),
      accentColor:
          _safeEnum(AccentColor.values, accentColorName, AccentColor.blue),
      appIconSize: (appIconSize ?? 96.0).clamp(80.0, 130.0),
      showAppLabels: showAppLabels ?? true,
      gridColumns: (gridColumns ?? 5).clamp(4, 6),
      speedLimitKmh: (speedLimitKmh ?? 80).clamp(30, 200),
      uiScale: uiScale ?? 0.0,
    );
  }

  LauncherSettings copyWith({
    bool? isDarkMode,
    bool? sidebarOnLeft,
    List<DashboardTile>? dashboardTiles,
    List<List<DashboardTile>>? dashboardPages,
    int? currentDashboardPage,
    List<String>? pinnedPackages,
    List<String>? sidebarDockPackages,
    Object? recentAppPackage = _sentinel,
    BackgroundStyle? backgroundStyle,
    AccentColor? accentColor,
    double? appIconSize,
    bool? showAppLabels,
    int? gridColumns,
    int? speedLimitKmh,
    double? uiScale,
  }) =>
      LauncherSettings(
        isDarkMode: isDarkMode ?? this.isDarkMode,
        sidebarOnLeft: sidebarOnLeft ?? this.sidebarOnLeft,
        dashboardTiles: dashboardTiles ?? this.dashboardTiles,
        dashboardPages: dashboardPages ?? this.dashboardPages,
        currentDashboardPage: currentDashboardPage ?? this.currentDashboardPage,
        pinnedPackages: pinnedPackages ?? this.pinnedPackages,
        sidebarDockPackages: (sidebarDockPackages ?? this.sidebarDockPackages).take(2).toList(),
        recentAppPackage: recentAppPackage == _sentinel
            ? this.recentAppPackage
            : recentAppPackage as String?,
        backgroundStyle: backgroundStyle ?? this.backgroundStyle,
        accentColor: accentColor ?? this.accentColor,
        appIconSize: appIconSize ?? this.appIconSize,
        showAppLabels: showAppLabels ?? this.showAppLabels,
        gridColumns: gridColumns ?? this.gridColumns,
        speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
        uiScale: uiScale ?? this.uiScale,
      );

  static const Object _sentinel = Object();

  static T _safeEnum<T extends Enum>(
      List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static List<DashboardTile> defaultTiles() => const [
        DashboardTile(id: 'main', type: DashboardTileType.map),
        DashboardTile(id: 'top_right', type: DashboardTileType.clock),
        DashboardTile(id: 'bottom_right', type: DashboardTileType.media),
      ];
}
