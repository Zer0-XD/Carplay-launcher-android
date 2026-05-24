import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/layout.dart';
import '../../pages/settings/settings_page.dart';
import '../../providers/app_list_provider.dart';
import '../../providers/edit_mode_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../domain/models/app_info.dart';

const String _kSettingsPkg = '__launcher_settings__';

/// App grid laid out as vertical swipeable pages, each page showing exactly
/// 2 rows × [columns] icons. The user swipes up/down to flip between pages.
class AppGridPage extends StatefulWidget {
  const AppGridPage({super.key});

  @override
  State<AppGridPage> createState() => _AppGridPageState();
}

class _AppGridPageState extends State<AppGridPage> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AppListProvider, SettingsProvider, EditModeProvider>(
      builder: (context, appList, settings, editMode, _) {
        if (appList.state == AppListState.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (appList.state == AppListState.error) {
          return Center(
            child: Text(
              appList.errorMessage ?? 'Failed to load apps',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        final pinned = settings.settings.pinnedPackages;
        final all = appList.apps;
        final ordered = _buildOrdered(pinned, all);

        final settingsEntry = AppInfo(
          packageName: _kSettingsPkg,
          label: 'Launcher Settings',
          iconBytes: null,
        );
        final appsWithSettings = [...ordered, settingsEntry];

        final iconSize = settings.settings.appIconSize;
        final columns = settings.settings.gridColumns;
        final showLabels = settings.settings.showAppLabels;
        const rowsPerPage = 2;

        return GestureDetector(
          onTap: editMode.isAppGridEditing ? editMode.exit : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final fittedColumns = _fitColumns(
                availableWidth: availableWidth,
                iconSize: iconSize,
                preferredColumns: columns,
              );

              final appsPerPage = fittedColumns * rowsPerPage;
              final pages = <List<AppInfo>>[];
              for (var i = 0; i < appsWithSettings.length; i += appsPerPage) {
                pages.add(appsWithSettings.sublist(
                  i,
                  (i + appsPerPage).clamp(0, appsWithSettings.length),
                ));
              }
              final totalPages = pages.isEmpty ? 1 : pages.length;

              return Column(
                children: [
                  Expanded(
                    child: editMode.isAppGridEditing
                        ? _ReorderablePage(
                            apps: ordered,
                            iconSize: iconSize,
                            columns: fittedColumns,
                            showLabels: showLabels,
                            onReorder: (oldIndex, newIndex) {
                              final updated = List<String>.from(
                                ordered.map((a) => a.packageName),
                              );
                              final item = updated.removeAt(oldIndex);
                              updated.insert(newIndex, item);
                              settings.reorderPinnedApps(updated);
                            },
                          )
                        : PageView.builder(
                            controller: _pageCtrl,
                            scrollDirection: Axis.vertical,
                            itemCount: totalPages,
                            onPageChanged: (p) =>
                                setState(() => _currentPage = p),
                            itemBuilder: (context, pageIdx) {
                              final pageApps = pageIdx < pages.length
                                  ? pages[pageIdx]
                                  : <AppInfo>[];
                              return _AppPage(
                                apps: pageApps,
                                iconSize: iconSize,
                                columns: fittedColumns,
                                showLabels: showLabels,
                                onTap: (app) {
                                  if (app.packageName == _kSettingsPkg) {
                                    SettingsPage.show(context).then((_) {
                                      SystemChrome.setEnabledSystemUIMode(
                                        SystemUiMode.immersiveSticky,
                                      );
                                    });
                                  } else {
                                    appList.launchApp(app.packageName);
                                    settings.setRecentApp(app.packageName);
                                  }
                                },
                                onLongPress: (_) =>
                                    editMode.enter(EditTarget.appGrid),
                              );
                            },
                          ),
                  ),

                  // Vertical page indicator dots
                  if (totalPages > 1 && !editMode.isAppGridEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: _VerticalPageDots(
                        current: _currentPage,
                        total: totalPages,
                        onTap: (i) => _pageCtrl.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  int _fitColumns({
    required double availableWidth,
    required double iconSize,
    required int preferredColumns,
  }) {
    const minPadding = Layout.appGridPaddingH * 2;
    const spacing = Layout.appGridSpacing;
    for (var cols = preferredColumns; cols >= 1; cols--) {
      final needed = cols * iconSize + (cols - 1) * spacing + minPadding;
      if (needed <= availableWidth) return cols;
    }
    return 1;
  }

  List<AppInfo> _buildOrdered(List<String> pinned, List<AppInfo> all) {
    final map = {for (final a in all) a.packageName: a};
    final result = <AppInfo>[];
    for (final pkg in pinned) {
      final app = map[pkg];
      if (app != null) result.add(app);
    }
    for (final app in all) {
      if (!pinned.contains(app.packageName)) result.add(app);
    }
    return result;
  }
}

// ── Single page of apps (2 rows × columns) ────────────────────────────────────

class _AppPage extends StatelessWidget {
  const _AppPage({
    required this.apps,
    required this.iconSize,
    required this.columns,
    required this.showLabels,
    required this.onTap,
    required this.onLongPress,
  });

  final List<AppInfo> apps;
  final double iconSize;
  final int columns;
  final bool showLabels;
  final ValueChanged<AppInfo> onTap;
  final ValueChanged<AppInfo> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: Layout.appGridPaddingH,
        vertical: Layout.appGridPaddingV,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: Layout.appGridSpacing,
        crossAxisSpacing: Layout.appGridSpacing,
        childAspectRatio: showLabels ? (iconSize / (iconSize + 28)) : 1.0,
      ),
      itemCount: apps.length,
      itemBuilder: (context, i) => Draggable<AppInfo>(
        data: apps[i],
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: _Md3IconBox(app: apps[i], size: iconSize),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _AppCell(
            app: apps[i],
            iconSize: iconSize,
            showLabel: showLabels,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
        child: _AppCell(
          app: apps[i],
          iconSize: iconSize,
          showLabel: showLabels,
          onTap: () => onTap(apps[i]),
          onLongPress: () => onLongPress(apps[i]),
        ),
      ),
    );
  }
}

// ── Reorderable grid (edit mode) ──────────────────────────────────────────────

class _ReorderablePage extends StatelessWidget {
  const _ReorderablePage({
    required this.apps,
    required this.iconSize,
    required this.columns,
    required this.showLabels,
    required this.onReorder,
  });

  final List<AppInfo> apps;
  final double iconSize;
  final int columns;
  final bool showLabels;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final rows = <List<AppInfo>>[];
    for (var i = 0; i < apps.length; i += columns) {
      rows.add(apps.sublist(i, (i + columns).clamp(0, apps.length)));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: Layout.appGridPaddingH,
        vertical: Layout.appGridPaddingV,
      ),
      itemCount: rows.length,
      onReorderItem: (oldRow, newRow) {
        onReorder(oldRow * columns, newRow * columns);
      },
      itemBuilder: (context, rowIndex) {
        final row = rows[rowIndex];
        return Padding(
          key: ValueKey(rowIndex),
          padding: const EdgeInsets.only(bottom: Layout.appGridSpacing),
          child: Row(
            children: [
              for (var i = 0; i < columns; i++)
                Expanded(
                  child: i < row.length
                      ? _AppCell(
                          app: row[i],
                          iconSize: iconSize,
                          showLabel: showLabels,
                          showEditBadge: true,
                          onTap: () {},
                          onLongPress: () {},
                        )
                      : const SizedBox(),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Single app cell ───────────────────────────────────────────────────────────

class _AppCell extends StatefulWidget {
  const _AppCell({
    required this.app,
    required this.iconSize,
    required this.showLabel,
    required this.onTap,
    required this.onLongPress,
    this.showEditBadge = false,
  });

  final AppInfo app;
  final double iconSize;
  final bool showLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showEditBadge;

  @override
  State<_AppCell> createState() => _AppCellState();
}

class _AppCellState extends State<_AppCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      onLongPress: () {
        _ctrl.forward();
        widget.onLongPress();
      },
      child: ScaleTransition(
        scale: _ctrl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Md3IconBox(app: widget.app, size: widget.iconSize, scheme: scheme),
                if (widget.showEditBadge) _EditBadge(size: widget.iconSize),
              ],
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 6),
              Text(
                widget.app.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withAlpha(200),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Circular icon box (user preferred style) ──────────────────────────────────

class _Md3IconBox extends StatelessWidget {
  const _Md3IconBox({required this.app, required this.size, this.scheme});

  final AppInfo app;
  final double size;
  final ColorScheme? scheme;

  @override
  Widget build(BuildContext context) {
    final cs = scheme ?? Theme.of(context).colorScheme;

    if (app.packageName == _kSettingsPkg) {
      return ClipOval(
        child: Container(
          width: size,
          height: size,
          color: cs.secondaryContainer,
          child: Icon(
            Icons.tune_rounded,
            color: cs.onSecondaryContainer,
            size: size * 0.50,
          ),
        ),
      );
    }

    final bytes = app.iconBytes;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: bytes != null
            ? Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: 96,
                cacheHeight: 96,
                gaplessPlayback: true,
              )
            : _FallbackIcon(label: app.label, size: size, scheme: cs),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({
    required this.label,
    required this.size,
    required this.scheme,
  });
  final String label;
  final double size;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: size * 0.40,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: -4,
      right: -4,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: scheme.error,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 1.5),
        ),
        child: Icon(Icons.remove, color: scheme.onError, size: 11),
      ),
    );
  }
}

// ── Page dots (horizontal row, for vertical page swipe) ───────────────────────

class _VerticalPageDots extends StatelessWidget {
  const _VerticalPageDots({
    required this.current,
    required this.total,
    required this.onTap,
  });

  final int current;
  final int total;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? scheme.primary : scheme.onSurface.withAlpha(60),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
