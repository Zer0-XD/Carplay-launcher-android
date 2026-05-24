/// Identifies which widget occupies a dashboard slot.
enum DashboardTileType {
  map,
  speedometer,
  clock,
  media,
  weather,
  quickControls,
  blank,
  androidWidget, // native Android app widget embedded via AppWidgetHost
}

/// A single configurable tile on the Dashboard page.
class DashboardTile {
  const DashboardTile({
    required this.id,
    required this.type,
    this.androidWidgetId,
    this.isFullWidth = false,
    this.widgetX = 0.0,
    this.widgetY = 0.0,
    this.widgetW = 0.6,
    this.widgetH = 1.0,
  });

  final String id;
  final DashboardTileType type;

  /// Set when [type] == [DashboardTileType.androidWidget].
  final int? androidWidgetId;

  /// Only meaningful for slot 0. Expands to full dashboard width.
  final bool isFullWidth;

  /// Free-position geometry for androidWidget tiles (fractions of canvas).
  /// (0,0) is top-left of the dashboard content area.
  final double widgetX;
  final double widgetY;
  final double widgetW;
  final double widgetH;

  DashboardTile copyWith({
    DashboardTileType? type,
    int? androidWidgetId,
    bool? isFullWidth,
    double? widgetX,
    double? widgetY,
    double? widgetW,
    double? widgetH,
  }) =>
      DashboardTile(
        id: id,
        type: type ?? this.type,
        androidWidgetId: androidWidgetId ?? this.androidWidgetId,
        isFullWidth: isFullWidth ?? this.isFullWidth,
        widgetX: widgetX ?? this.widgetX,
        widgetY: widgetY ?? this.widgetY,
        widgetW: widgetW ?? this.widgetW,
        widgetH: widgetH ?? this.widgetH,
      );

  DashboardTile withAndroidWidget(int widgetId) => DashboardTile(
        id: id,
        type: DashboardTileType.androidWidget,
        androidWidgetId: widgetId,
        isFullWidth: isFullWidth,
        widgetX: widgetX,
        widgetY: widgetY,
        widgetW: widgetW,
        widgetH: widgetH,
      );

  DashboardTile clearAndroidWidget() => DashboardTile(id: id, type: DashboardTileType.blank);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (androidWidgetId != null) 'androidWidgetId': androidWidgetId,
        if (isFullWidth) 'isFullWidth': true,
        'widgetX': widgetX,
        'widgetY': widgetY,
        'widgetW': widgetW,
        'widgetH': widgetH,
      };

  factory DashboardTile.fromJson(Map<String, dynamic> json) => DashboardTile(
        id: json['id'] as String,
        type: DashboardTileType.values.byName(
          json['type'] as String? ?? DashboardTileType.blank.name,
        ),
        androidWidgetId: json['androidWidgetId'] as int?,
        isFullWidth: json['isFullWidth'] as bool? ?? false,
        widgetX: (json['widgetX'] as num?)?.toDouble() ?? 0.0,
        widgetY: (json['widgetY'] as num?)?.toDouble() ?? 0.0,
        widgetW: (json['widgetW'] as num?)?.toDouble() ?? 0.6,
        widgetH: (json['widgetH'] as num?)?.toDouble() ?? 1.0,
      );
}
