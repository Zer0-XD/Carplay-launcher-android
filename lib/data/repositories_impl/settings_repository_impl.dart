import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/dashboard_tile.dart';
import '../../domain/models/launcher_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _kDarkMode = 'dark_mode';
  static const _kSidebarLeft = 'sidebar_left';
  static const _kDashTiles = 'dash_tiles';
  static const _kDashPages = 'dash_pages';
  static const _kCurrentDashPage = 'current_dash_page';
  static const _kPinned = 'pinned_packages';
  static const _kDock = 'sidebar_dock_packages';
  static const _kRecent = 'recent_app_package';
  static const _kBackground = 'background_style';
  static const _kAccent = 'accent_color';
  static const _kIconSize = 'app_icon_size';
  static const _kShowLabels = 'show_app_labels';
  static const _kGridColumns = 'grid_columns';
  static const _kSpeedLimit = 'speed_limit_kmh';
  static const _kUiScale = 'ui_scale';

  @override
  Future<LauncherSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    List<DashboardTile>? tiles;
    final tilesJson = prefs.getString(_kDashTiles);
    if (tilesJson != null) {
      try {
        final decoded = jsonDecode(tilesJson) as List<dynamic>;
        tiles = decoded
            .map((e) => DashboardTile.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }

    List<List<DashboardTile>>? pages;
    final pagesJson = prefs.getString(_kDashPages);
    if (pagesJson != null) {
      try {
        final decoded = jsonDecode(pagesJson) as List<dynamic>;
        pages = decoded.map((page) {
          final tileList = page as List<dynamic>;
          return tileList
              .map((e) => DashboardTile.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }).toList();
      } catch (_) {}
    }

    return LauncherSettings.fromPrefs(
      isDarkMode: prefs.getBool(_kDarkMode),
      sidebarOnLeft: prefs.getBool(_kSidebarLeft),
      dashboardTiles: tiles,
      dashboardPages: pages,
      currentDashboardPage: prefs.getInt(_kCurrentDashPage),
      pinnedPackages: prefs.getStringList(_kPinned),
      sidebarDockPackages: prefs.getStringList(_kDock),
      recentAppPackage: prefs.getString(_kRecent),
      backgroundStyleName: prefs.getString(_kBackground),
      accentColorName: prefs.getString(_kAccent),
      appIconSize: prefs.getDouble(_kIconSize),
      showAppLabels: prefs.getBool(_kShowLabels),
      gridColumns: prefs.getInt(_kGridColumns),
      speedLimitKmh: prefs.getInt(_kSpeedLimit),
      uiScale: prefs.getDouble(_kUiScale),
    );
  }

  @override
  Future<void> save(LauncherSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool(_kDarkMode, s.isDarkMode),
      prefs.setBool(_kSidebarLeft, s.sidebarOnLeft),
      prefs.setString(_kDashTiles,
          jsonEncode(s.dashboardTiles.map((t) => t.toJson()).toList())),
      prefs.setString(_kDashPages,
          jsonEncode(s.dashboardPages.map((page) => page.map((t) => t.toJson()).toList()).toList())),
      prefs.setInt(_kCurrentDashPage, s.currentDashboardPage),
      prefs.setStringList(_kPinned, s.pinnedPackages),
      prefs.setStringList(_kDock, s.sidebarDockPackages),
      s.recentAppPackage != null
          ? prefs.setString(_kRecent, s.recentAppPackage!)
          : prefs.remove(_kRecent),
      prefs.setString(_kBackground, s.backgroundStyle.name),
      prefs.setString(_kAccent, s.accentColor.name),
      prefs.setDouble(_kIconSize, s.appIconSize),
      prefs.setBool(_kShowLabels, s.showAppLabels),
      prefs.setInt(_kGridColumns, s.gridColumns),
      prefs.setInt(_kSpeedLimit, s.speedLimitKmh),
      prefs.setDouble(_kUiScale, s.uiScale),
    ]);
  }
}
