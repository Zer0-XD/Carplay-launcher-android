import '../../domain/models/app_info.dart';
import '../../domain/repositories/app_repository.dart';
import '../services/native_app_service.dart';

class AppRepositoryImpl implements AppRepository {
  const AppRepositoryImpl(this._service);

  final NativeAppService _service;

  @override
  Future<List<AppInfo>> getInstalledApps() => _service.fetchInstalledApps();

  @override
  Future<void> launchApp(String packageName) =>
      _service.launchApp(packageName);
}
