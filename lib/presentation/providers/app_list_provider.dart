import 'package:flutter/foundation.dart';
import '../../domain/models/app_info.dart';
import '../../domain/repositories/app_repository.dart';

enum AppListState { idle, loading, loaded, error }

/// Manages the list of installed apps fetched via [AppRepository].
///
/// Uses an LRU-safe fixed list — no live icon decoding in the provider;
/// icons are decoded lazily inside [AppIconWidget].
class AppListProvider extends ChangeNotifier {
  AppListProvider(this._repo);

  final AppRepository _repo;

  AppListState _state = AppListState.idle;
  List<AppInfo> _apps = const [];
  String? _errorMessage;

  AppListState get state => _state;
  List<AppInfo> get apps => _apps;
  String? get errorMessage => _errorMessage;

  Future<void> loadApps() async {
    if (_state == AppListState.loading) return;
    _state = AppListState.loading;
    notifyListeners();

    try {
      _apps = await _repo.getInstalledApps();
      _state = AppListState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AppListState.error;
    }
    notifyListeners();
  }

  Future<void> launchApp(String packageName) =>
      _repo.launchApp(packageName);

  /// Returns the [AppInfo] for a package name, or null if not found.
  AppInfo? infoFor(String packageName) {
    for (final app in _apps) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }
}
