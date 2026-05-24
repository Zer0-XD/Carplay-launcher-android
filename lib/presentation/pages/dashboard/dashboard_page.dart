import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/dashboard_tile.dart';
import '../../providers/edit_mode_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../data/services/app_widget_service.dart';
import '../../widgets/android_widget_picker.dart';
import '../../widgets/cards/android_widget_card.dart';
import '../../widgets/cards/clock_card.dart';
import '../../widgets/cards/map_card.dart';
import '../../widgets/cards/media_card.dart';
import '../../widgets/cards/speed_card.dart';
import '../../widgets/cards/weather_card.dart';
import '../../widgets/cards/quick_controls_card.dart';

// ── CarPlay 60/40 layout ──────────────────────────────────────────────────────
//
//   ┌──────────────────────┬───────────────┐
//   │                      │     [1]       │
//   │        [0]           ├───────────────┤
//   │      (large)         │     [2]       │
//   └──────────────────────┴───────────────┘
//        ~60% width              ~40% width
//
// Three fixed slots. User long-presses any slot → bottom-sheet type picker.
// Layout never breaks — no dragging, no resizing.

const int _kSlotCount = 3;

DashboardTile _blank(int i) => DashboardTile(
      id: 'slot_$i',
      type: DashboardTileType.blank,
    );

List<DashboardTile> _normalise(List<DashboardTile> src) {
  final out = List<DashboardTile>.from(src.take(_kSlotCount));
  while (out.length < _kSlotCount) {
    out.add(_blank(out.length));
  }
  return out;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.pageIndex = 0});
  final int pageIndex;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _hoveredSlot = -1;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, EditModeProvider>(
      builder: (context, settings, editMode, _) {
        final pages = settings.settings.dashboardPages;
        final pageIdx =
            widget.pageIndex.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
        final raw = pages.isNotEmpty
            ? pages[pageIdx]
            : settings.settings.activeTiles;
        final tiles = _normalise(raw);
        final editing = editMode.isDashboardEditing;

        if (!editing && _hoveredSlot != -1) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => setState(() => _hoveredSlot = -1));
        }

        // Tapping outside any card dismisses edit mode
        return GestureDetector(
          onTap: editing ? editMode.exit : null,
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // ── Left: large card (~60%) ──────────────────────────────────
                Expanded(
                  flex: 60,
                  child: _Slot(
                    tile: tiles[0],
                    slotIndex: 0,
                    editing: editing,
                    hovered: editing && _hoveredSlot == 0,
                    onTap: () => _pickType(context, 0, tiles, editing,
                        editMode, settings, pageIdx),
                    onEnter: () => setState(() => _hoveredSlot = 0),
                    onExit: () => setState(() => _hoveredSlot = -1),
                  ),
                ),

                const SizedBox(width: 10),

                // ── Right: two stacked cards (~40%) ──────────────────────────
                Expanded(
                  flex: 40,
                  child: Column(
                    children: [
                      Expanded(
                        child: _Slot(
                          tile: tiles[1],
                          slotIndex: 1,
                          editing: editing,
                          hovered: editing && _hoveredSlot == 1,
                          onTap: () => _pickType(context, 1, tiles, editing,
                              editMode, settings, pageIdx),
                          onEnter: () => setState(() => _hoveredSlot = 1),
                          onExit: () => setState(() => _hoveredSlot = -1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _Slot(
                          tile: tiles[2],
                          slotIndex: 2,
                          editing: editing,
                          hovered: editing && _hoveredSlot == 2,
                          onTap: () => _pickType(context, 2, tiles, editing,
                              editMode, settings, pageIdx),
                          onEnter: () => setState(() => _hoveredSlot = 2),
                          onExit: () => setState(() => _hoveredSlot = -1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickType(
    BuildContext context,
    int slotIndex,
    List<DashboardTile> tiles,
    bool editing,
    EditModeProvider editMode,
    SettingsProvider settings,
    int pageIdx,
  ) async {
    if (!editing) {
      editMode.enter(EditTarget.dashboard, tileIndex: slotIndex);
      return;
    }

    final result = await _TypePicker.show(context, current: tiles[slotIndex].type);
    if (result == null || !context.mounted) return;

    final t = tiles[slotIndex];
    DashboardTile updated;

    if (result == DashboardTileType.androidWidget) {
      final widgetId = await showAndroidWidgetPicker(context);
      if (widgetId == null || !context.mounted) return;
      if (t.androidWidgetId != null) {
        AppWidgetService.instance.deleteWidget(t.androidWidgetId!);
      }
      updated = t.withAndroidWidget(widgetId);
    } else {
      if (t.androidWidgetId != null) {
        AppWidgetService.instance.deleteWidget(t.androidWidgetId!);
      }
      updated = t.copyWith(type: result);
    }

    final newList = List<DashboardTile>.from(tiles)..[slotIndex] = updated;
    settings.reorderDashboardTiles(newList, pageIndex: pageIdx);
    if (context.mounted) editMode.exit();
  }
}

// ── Single slot ───────────────────────────────────────────────────────────────

class _Slot extends StatelessWidget {
  const _Slot({
    required this.tile,
    required this.slotIndex,
    required this.editing,
    required this.hovered,
    required this.onTap,
    required this.onEnter,
    required this.onExit,
  });

  final DashboardTile tile;
  final int slotIndex;
  final bool editing;
  final bool hovered;
  final VoidCallback onTap;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onTap,
      child: MouseRegion(
        onEnter: (_) => onEnter(),
        onExit: (_) => onExit(),
        child: AnimatedScale(
          scale: hovered ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: editing
                  ? Border.all(
                      color: hovered
                          ? scheme.primary
                          : scheme.outline.withAlpha(90),
                      width: hovered ? 2.5 : 1.5,
                    )
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Content card
                  _buildCard(context),

                  // Edit-mode tonal scrim
                  if (editing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          color: hovered
                              ? scheme.primary.withAlpha(30)
                              : Colors.black.withAlpha(18),
                        ),
                      ),
                    ),

                  // "Change" chip — top-right corner
                  if (editing)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IgnorePointer(
                        child: _EditChip(hovered: hovered),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    if (tile.type == DashboardTileType.androidWidget &&
        tile.androidWidgetId != null) {
      return AndroidWidgetCard(
        appWidgetId: tile.androidWidgetId!,
        isEditing: editing,
        onLongPress: onTap,
        onMove: null,
        onResize: null,
      );
    }
    switch (tile.type) {
      case DashboardTileType.androidWidget:
        return _EmptySlot(onTap: onTap);
      case DashboardTileType.speedometer:
        return SpeedCard(isEditing: false, onLongPress: onTap, isLarge: true);
      case DashboardTileType.map:
        return MapCard(isEditing: false, onLongPress: onTap);
      case DashboardTileType.clock:
        return ClockCard(isEditing: false, onLongPress: onTap, isLarge: true);
      case DashboardTileType.media:
        return MediaCard(isEditing: false, onLongPress: onTap, isLarge: true);
      case DashboardTileType.weather:
        return WeatherCard(isEditing: false, onLongPress: onTap, isLarge: true);
      case DashboardTileType.quickControls:
        return QuickControlsCard(
            isEditing: false, onLongPress: onTap, isLarge: true);
      case DashboardTileType.blank:
        return _EmptySlot(onTap: onTap);
    }
  }
}

// ── Edit chip ─────────────────────────────────────────────────────────────────

class _EditChip extends StatelessWidget {
  const _EditChip({required this.hovered});
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hovered ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withAlpha(70),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.edit_rounded,
            size: 11,
            color: hovered ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'Change',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: hovered ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty / blank slot ────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 28,
                color: scheme.onSurface.withAlpha(50),
              ),
              const SizedBox(height: 8),
              Text(
                'Long press to set',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurface.withAlpha(50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type picker bottom-sheet ──────────────────────────────────────────────────

class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.current});
  final DashboardTileType current;

  static const _options = [
    (DashboardTileType.clock,        Icons.access_time_rounded,     'Clock',    'Time & date'),
    (DashboardTileType.media,        Icons.music_note_rounded,      'Media',    'Now playing'),
    (DashboardTileType.weather,      Icons.wb_sunny_rounded,        'Weather',  'Forecast'),
    (DashboardTileType.speedometer,  Icons.speed_rounded,           'Speed',    'GPS speed'),
    (DashboardTileType.map,          Icons.map_rounded,             'Map',      'Navigation'),
    (DashboardTileType.quickControls,Icons.tune_rounded,            'Controls', 'Vol & Wi-Fi'),
    (DashboardTileType.androidWidget,Icons.widgets_rounded,         'Widget',   'Android widget'),
    (DashboardTileType.blank,        Icons.crop_square_rounded,     'Empty',    'Clear slot'),
  ];

  static Future<DashboardTileType?> show(
    BuildContext context, {
    required DashboardTileType current,
  }) =>
      showModalBottomSheet<DashboardTileType>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _TypePicker(current: current),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose content',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),

          // 4-column option grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.88,
            children: _options.map((opt) {
              final (type, icon, label, sub) = opt;
              final active = type == current;
              return GestureDetector(
                onTap: () => Navigator.pop(context, type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: active
                        ? Border.all(color: scheme.secondary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: active
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 9,
                          color: active
                              ? scheme.onSecondaryContainer.withAlpha(180)
                              : scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
