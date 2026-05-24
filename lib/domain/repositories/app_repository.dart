import '../models/app_info.dart';

abstract interface class AppRepository {
  /// Returns the full list of launchable apps from the device.
  Future<List<AppInfo>> getInstalledApps();

  /// Launches [packageName] via an Android Intent.
  Future<void> launchApp(String packageName);
}
