import 'package:flutter/material.dart';
import '../../data/services/app_widget_service.dart';

/// Shows a full-screen bottom sheet listing all installed Android app widgets
/// grouped by app, with a preview image grid per app.
/// Returns the bound appWidgetId on success, or null if cancelled.
Future<int?> showAndroidWidgetPicker(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => const _WidgetPickerSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _WidgetPickerSheet extends StatefulWidget {
  const _WidgetPickerSheet();

  @override
  State<_WidgetPickerSheet> createState() => _WidgetPickerSheetState();
}

class _WidgetPickerSheetState extends State<_WidgetPickerSheet> {
  List<WidgetInfo> _all = [];
  String _query = '';
  bool _loading = true;

  // groups: appLabel → list of widgets from that app
  Map<String, List<WidgetInfo>> _groups = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final widgets = await AppWidgetService.instance.getAvailableWidgets();
      widgets.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      if (mounted) {
        setState(() {
          _all = widgets;
          _groups = _buildGroups(widgets);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<WidgetInfo>> _buildGroups(List<WidgetInfo> widgets) {
    final map = <String, List<WidgetInfo>>{};
    for (final w in widgets) {
      // Use the package name's last segment as a readable app name fallback
      final appKey = _appName(w);
      (map[appKey] ??= []).add(w);
    }
    // Sort app groups alphabetically
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String _appName(WidgetInfo w) {
    // package → "com.google.android.apps.maps" → "Maps"
    final parts = w.package.split('.');
    if (parts.length >= 2) {
      final last = parts.last;
      if (last.length > 2 && !last.startsWith('android')) {
        return _capitalise(last);
      }
      if (parts.length >= 3) return _capitalise(parts[parts.length - 2]);
    }
    return _capitalise(w.package);
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  List<MapEntry<String, List<WidgetInfo>>> get _filtered {
    if (_query.isEmpty) return _groups.entries.toList();
    final q = _query.toLowerCase();
    final result = <MapEntry<String, List<WidgetInfo>>>[];
    for (final entry in _groups.entries) {
      final matching = entry.value
          .where((w) =>
              w.label.toLowerCase().contains(q) ||
              w.package.toLowerCase().contains(q))
          .toList();
      if (matching.isNotEmpty) result.add(MapEntry(entry.key, matching));
    }
    return result;
  }

  Future<void> _pick(WidgetInfo info) async {
    try {
      final id = await AppWidgetService.instance.allocateWidgetId();
      if (id < 0) return;
      final boundId = await AppWidgetService.instance.bindWidget(
        appWidgetId: id,
        provider: info.provider,
      );
      if (mounted) Navigator.of(context).pop(boundId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add widget: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withAlpha(40),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.widgets_rounded,
                          color: scheme.onSecondaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Widget',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${_all.length} available',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Search ─────────────────────────────────────────────────
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search widgets…',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded,
                                  size: 18, color: scheme.onSurfaceVariant),
                              onPressed: () => setState(() => _query = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: scheme.primary,
                            strokeWidth: 2.5,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Loading widgets…',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 48,
                                  color: scheme.onSurface.withAlpha(50)),
                              const SizedBox(height: 12),
                              Text(
                                'No widgets match "$_query"',
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _AppGroup(
                            appName: filtered[i].key,
                            widgets: filtered[i].value,
                            onPick: _pick,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App group (collapsible section header + widget cards) ─────────────────────

class _AppGroup extends StatefulWidget {
  const _AppGroup({
    required this.appName,
    required this.widgets,
    required this.onPick,
  });

  final String appName;
  final List<WidgetInfo> widgets;
  final Future<void> Function(WidgetInfo) onPick;

  @override
  State<_AppGroup> createState() => _AppGroupState();
}

class _AppGroupState extends State<_AppGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ─────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  // App initial badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.appName.isNotEmpty
                          ? widget.appName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.appName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Text(
                    '${widget.widgets.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Widget card grid ──────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _expanded
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: widget.widgets.length,
                    itemBuilder: (_, i) => _WidgetCard(
                      info: widget.widgets[i],
                      onTap: () => widget.onPick(widget.widgets[i]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Single widget card ────────────────────────────────────────────────────────

class _WidgetCard extends StatefulWidget {
  const _WidgetCard({required this.info, required this.onTap});

  final WidgetInfo info;
  final VoidCallback onTap;

  @override
  State<_WidgetCard> createState() => _WidgetCardState();
}

class _WidgetCardState extends State<_WidgetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94,
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
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withAlpha(140),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Preview image or placeholder
              if (widget.info.previewImage != null)
                Positioned.fill(
                  child: Image.memory(
                    widget.info.previewImage!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                )
              else
                Center(
                  child: Icon(
                    Icons.widgets_outlined,
                    size: 32,
                    color: scheme.onSurface.withAlpha(40),
                  ),
                ),

              // Bottom label bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.info.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Size badge — top-right
              if (widget.info.minWidth > 0 || widget.info.minHeight > 0)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.info.minWidth}×${widget.info.minHeight}dp',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
