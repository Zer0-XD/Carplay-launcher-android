import '../models/launcher_settings.dart';

abstract interface class SettingsRepository {
  Future<LauncherSettings> load();
  Future<void> save(LauncherSettings settings);
}
