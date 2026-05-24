import 'dart:typed_data';

/// Represents a single installed Android application.
class AppInfo {
  const AppInfo({
    required this.packageName,
    required this.label,
    required this.iconBytes,
  });

  final String packageName;
  final String label;

  /// Raw PNG/JPEG bytes decoded on the native side at 96×96 px — kept small
  /// to stay within the 2 GB RAM budget.
  final Uint8List? iconBytes;

  AppInfo copyWith({Uint8List? iconBytes}) => AppInfo(
        packageName: packageName,
        label: label,
        iconBytes: iconBytes ?? this.iconBytes,
      );

  @override
  bool operator ==(Object other) =>
      other is AppInfo && other.packageName == packageName;

  @override
  int get hashCode => packageName.hashCode;
}
