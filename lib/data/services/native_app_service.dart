import 'package:flutter/services.dart';
import '../../domain/models/app_info.dart';

/// MethodChannel façade — all calls to the Kotlin side live here.
class NativeAppService {
  NativeAppService._();
  static final NativeAppService instance = NativeAppService._();

  static const _channel = MethodChannel('com.zero.dashflow_launcher/apps');

  /// Fetches installed apps from Android. Returns a list where each entry is:
  ///   { 'packageName': String, 'label': String, 'icon': Uint8List? }
  ///
  /// Icons are pre-scaled to 96×96 on the native side to avoid large
  /// Uint8List copies in the Dart heap.
  Future<List<AppInfo>> fetchInstalledApps() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    if (raw == null) return const [];

    return raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final iconBytes = m['icon'];
      return AppInfo(
        packageName: m['packageName'] as String,
        label: m['label'] as String,
        iconBytes: iconBytes is Uint8List ? iconBytes : null,
      );
    }).toList(growable: false);
  }

  Future<void> launchApp(String packageName) =>
      _channel.invokeMethod('launchApp', {'packageName': packageName});
}
