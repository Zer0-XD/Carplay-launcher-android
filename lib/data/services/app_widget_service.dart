import 'package:flutter/services.dart';

/// Dart interface to the AppWidgetChannel on the Android side.
class AppWidgetService {
  AppWidgetService._();
  static final instance = AppWidgetService._();

  static const _channel = MethodChannel('com.zero.dashflow_launcher/widgets');

  /// Returns all installed Android app widgets with label, preview image, etc.
  Future<List<WidgetInfo>> getAvailableWidgets() async {
    final list = await _channel.invokeListMethod<Map>('getAvailableWidgets') ?? [];
    return list.map((e) => WidgetInfo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  /// Allocates a new AppWidget ID from the host. Call before binding.
  Future<int> allocateWidgetId() async {
    return await _channel.invokeMethod<int>('allocateWidgetId') ?? -1;
  }

  /// Binds a provider to an allocated ID. May show the system bind-permission
  /// dialog or the widget's own configuration activity.
  /// Returns the final bound widget ID on success.
  Future<int> bindWidget({required int appWidgetId, required String provider}) async {
    return await _channel.invokeMethod<int>('bindWidget', {
          'appWidgetId': appWidgetId,
          'provider': provider,
        }) ??
        -1;
  }

  /// Releases the widget ID so Android can reclaim resources.
  Future<void> deleteWidget(int appWidgetId) async {
    await _channel.invokeMethod<void>('deleteWidget', {'appWidgetId': appWidgetId});
  }
}

class WidgetInfo {
  const WidgetInfo({
    required this.provider,
    required this.label,
    required this.package,
    this.previewImage,
    this.minWidth = 0,
    this.minHeight = 0,
  });

  final String provider;
  final String label;
  final String package;
  final Uint8List? previewImage;
  final int minWidth;
  final int minHeight;

  factory WidgetInfo.fromMap(Map<String, dynamic> map) => WidgetInfo(
        provider: map['provider'] as String,
        label: map['label'] as String,
        package: map['package'] as String,
        previewImage: map['previewImage'] != null
            ? Uint8List.fromList((map['previewImage'] as List).cast<int>())
            : null,
        minWidth: (map['minWidth'] as num?)?.toInt() ?? 0,
        minHeight: (map['minHeight'] as num?)?.toInt() ?? 0,
      );
}
