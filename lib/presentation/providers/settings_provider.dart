import 'package:flutter/foundation.dart';
import '../../domain/models/dashboard_tile.dart';
import '../../domain/models/launcher_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repo);

  final SettingsRepository _repo;
  LauncherSettings _settings = const LauncherSettings();

  LauncherSettings get settings => _settings;
  bool get isDarkMode => _settings.isDarkMode;
  bool get sidebarOnLeft => _settings.sidebarOnLeft;

  Future<void> load() async {
    _settings = await _repo.load();
    notifyListeners();
  }

  Future<void> toggleTheme() =>
      _update(_settings.copyWith(isDarkMode: !_settings.isDarkMode));

  Future<void> toggleSidebarSide() =>
      _update(_settings.copyWith(sidebarOnLeft: !_settings.sidebarOnLeft));

  Future<void> setBackground(BackgroundStyle style) =>
      _update(_settings.copyWith(backgroundStyle: style));

  Future<void> setAccentColor(AccentColor color) =>
      _update(_settings.copyWith(accentColor: color));

  Future<void> setIconSize(double size) =>
      _update(_settings.copyWith(appIconSize: size));

  Future<void> toggleAppLabels() =>
      _update(_settings.copyWith(showAppLabels: !_settings.showAppLabels));

  Future<void> setGridColumns(int columns) =>
      _update(_settings.copyWith(gridColumns: columns));

  Future<void> setSpeedLimit(int kmh) =>
      _update(_settings.copyWith(speedLimitKmh: kmh.clamp(30, 200)));

  Future<void> setUiScale(double scale) =>
      _update(_settings.copyWith(uiScale: scale));

  Future<void> reorderDashboardTiles(List<DashboardTile> tiles, {int? pageIndex}) {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages);
    final idx = (pageIndex ?? _settings.currentDashboardPage).clamp(0, pages.length - 1);
    pages[idx] = tiles;
    return _update(_settings.copyWith(dashboardTiles: tiles, dashboardPages: pages));
  }

  Future<void> saveTileGeometry(
    int tileIndex, {
    required double x,
    required double y,
    required double w,
    required double h,
    int? pageIndex,
  }) {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages);
    final idx = (pageIndex ?? _settings.currentDashboardPage).clamp(0, pages.length - 1);
    final tiles = List<DashboardTile>.from(pages[idx]);
    if (tileIndex >= tiles.length) return Future.value();
    tiles[tileIndex] = tiles[tileIndex].copyWith(
      widgetX: x.clamp(0.0, 1.0),
      widgetY: y.clamp(0.0, 1.0),
      widgetW: w.clamp(0.1, 1.0),
      widgetH: h.clamp(0.1, 1.0),
    );
    pages[idx] = tiles;
    return _update(_settings.copyWith(dashboardTiles: tiles, dashboardPages: pages));
  }

  Future<void> removeTile(int tileIndex, {int? pageIndex}) {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages);
    final idx = (pageIndex ?? _settings.currentDashboardPage).clamp(0, pages.length - 1);
    final tiles = List<DashboardTile>.from(pages[idx]);
    if (tileIndex >= tiles.length) return Future.value();
    tiles.removeAt(tileIndex);
    pages[idx] = tiles;
    return _update(_settings.copyWith(dashboardTiles: tiles, dashboardPages: pages));
  }

  Future<void> addTile(DashboardTile tile, {int? pageIndex}) {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages);
    final idx = (pageIndex ?? _settings.currentDashboardPage).clamp(0, pages.length - 1);
    final tiles = List<DashboardTile>.from(pages[idx])..add(tile);
    pages[idx] = tiles;
    return _update(_settings.copyWith(dashboardTiles: tiles, dashboardPages: pages));
  }

  Future<void> toggleTileFullWidth(int tileIndex, {int? pageIndex}) {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages);
    final idx = (pageIndex ?? _settings.currentDashboardPage).clamp(0, pages.length - 1);
    final tiles = List<DashboardTile>.from(pages[idx]);
    if (tileIndex >= tiles.length) return Future.value();
    tiles[tileIndex] = tiles[tileIndex].copyWith(isFullWidth: !tiles[tileIndex].isFullWidth);
    pages[idx] = tiles;
    return _update(_settings.copyWith(dashboardTiles: tiles, dashboardPages: pages));
  }

  Future<void> addDashboardPage() {
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages)
      ..add(LauncherSettings.defaultTiles());
    return _update(_settings.copyWith(
      dashboardPages: pages,
      currentDashboardPage: pages.length - 1,
    ));
  }

  Future<void> removeDashboardPage(int index) {
    if (_settings.dashboardPages.length <= 1) return Future.value();
    final pages = List<List<DashboardTile>>.from(_settings.dashboardPages)
      ..removeAt(index);
    final newIdx = _settings.currentDashboardPage.clamp(0, pages.length - 1);
    return _update(_settings.copyWith(
      dashboardPages: pages,
      currentDashboardPage: newIdx,
    ));
  }

  Future<void> setCurrentDashboardPage(int index) {
    final clamped = index.clamp(0, _settings.dashboardPages.length - 1);
    if (clamped == _settings.currentDashboardPage) return Future.value();
    return _update(_settings.copyWith(currentDashboardPage: clamped));
  }

  Future<void> reorderPinnedApps(List<String> packages) =>
      _update(_settings.copyWith(pinnedPackages: packages));

  Future<void> addToDock(String packageName) {
    if (_settings.sidebarDockPackages.contains(packageName)) return Future.value();
    final updated = [..._settings.sidebarDockPackages, packageName].take(2).toList();
    return _update(_settings.copyWith(sidebarDockPackages: updated));
  }

  Future<void> removeFromDock(String packageName) {
    final updated = _settings.sidebarDockPackages.where((p) => p != packageName).toList();
    return _update(_settings.copyWith(sidebarDockPackages: updated));
  }

  Future<void> setRecentApp(String packageName) =>
      _update(_settings.copyWith(recentAppPackage: packageName));

  Future<void> _update(LauncherSettings next) async {
    _settings = next;
    notifyListeners();
    await _repo.save(next);
  }
}
