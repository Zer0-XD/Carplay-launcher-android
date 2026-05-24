// NO BackdropFilter / ImageFilter in this file — they tank the GPU on 2 GB
// headunits. Glass look is achieved with flat semi-transparent colours only.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/bluetooth_service.dart';
import '../../../data/services/system_stats_service.dart';
import '../../../domain/models/app_info.dart';
import '../../../main.dart' show UiScaleContext;
import '../../providers/app_list_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/app_icon_widget.dart';
import 'live_clock.dart';
import 'wifi_panel.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({
    super.key,
    required this.pageController,
    required this.currentPage,
    this.onOpenAppDrawer,
  });

  final PageController pageController;
  final int currentPage;
  final VoidCallback? onOpenAppDrawer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppColors.dark : AppColors.light;

    // Use context.select so this widget only rebuilds when the specific fields
    // it cares about change — not on every SettingsProvider/AppListProvider tick.
    final dockPackages = context.select<SettingsProvider, List<String>>(
      (sp) => sp.settings.sidebarDockPackages,
    );
    final recentPkg = context.select<SettingsProvider, String?>(
      (sp) => sp.settings.recentAppPackage,
    );
    final dockApps = context.select<AppListProvider, List<AppInfo?>>(
      (al) => dockPackages.map((pkg) => al.infoFor(pkg)).toList(),
    );
    final recentApp = recentPkg != null
        ? context.select<AppListProvider, AppInfo?>(
            (al) => al.infoFor(recentPkg),
          )
        : null;

    // LayoutBuilder gives us the sidebar's real allocated height so every
    // element can be sized as a fraction of it — no hardcoded pixel values.
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        final gap = (h * 0.012).clamp(4.0, 10.0);

        const kFixedOverhead = 110.0;
        const kIconSlots = 4;
        final maxIconFromHeight = (h - kFixedOverhead - gap * 12) / kIconSlots;
        final iconSize = (w * 0.75).clamp(
          36.0,
          maxIconFromHeight.clamp(36.0, 68.0),
        );

        final scheme = Theme.of(context).colorScheme;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withAlpha(120),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(height: gap * 1.2),

                // ── Clock (RepaintBoundary: ticks every second) ────────────────
                const RepaintBoundary(child: LiveClock(compact: true)),

                SizedBox(height: gap * 0.8),

                // ── WiFi + Bluetooth ───────────────────────────────────────────
                const RepaintBoundary(child: _StatusIcons()),

                SizedBox(height: gap),
                _Divider(w: w),
                SizedBox(height: gap),

                // ── App drawer button ──────────────────────────────────────────
                _AppDrawerButton(
                  isOnApps: false,
                  accent: colors.accent,
                  iconSize: iconSize,
                  onTap: onOpenAppDrawer ?? () {},
                ),

                SizedBox(height: gap),
                SizedBox(height: gap),

                // ── Pinned dock slots (2) ──────────────────────────────────────
                ...List.generate(2, (i) {
                  final app = i < dockApps.length ? dockApps[i] : null;
                  return Padding(
                    padding: EdgeInsets.only(bottom: gap),
                    child: _DockSlot(
                      app: app,
                      iconSize: iconSize,
                      onTap: app == null
                          ? null
                          : () {
                              context.read<AppListProvider>().launchApp(
                                app.packageName,
                              );
                              context.read<SettingsProvider>().setRecentApp(
                                app.packageName,
                              );
                            },
                      onRemove: app == null
                          ? null
                          : () => context
                                .read<SettingsProvider>()
                                .removeFromDock(app.packageName),
                      onDrop: (dropped) => context
                          .read<SettingsProvider>()
                          .addToDock(dropped.packageName),
                    ),
                  );
                }),

                SizedBox(height: gap * 0.5),

                // ── Recent slot (1) ───────────────────────────────────────────
                _Divider(w: w),
                SizedBox(height: gap),
                _SidebarLabel('RECENT', w: w),
                SizedBox(height: gap),
                _RecentSlot(
                  app: recentApp,
                  iconSize: iconSize,
                  onTap: recentApp == null
                      ? null
                      : () {
                          context.read<AppListProvider>().launchApp(
                            recentApp.packageName,
                          );
                          context.read<SettingsProvider>().setRecentApp(
                            recentApp.packageName,
                          );
                        },
                ),

                SizedBox(height: gap * 1.2),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.w});
  final double w;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: w * 0.15),
      height: 1,
      color: scheme.outlineVariant,
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.text, {required this.w});
  final String text;
  final double w;

  @override
  Widget build(BuildContext context) {
    final scale = context.uiScale;
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: (8 * scale).clamp(7.0, 11.0),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: scheme.onSurfaceVariant.withAlpha(180),
      ),
    );
  }
}

// ── Status icons ──────────────────────────────────────────────────────────────

// Combines both streams into a single value so we only rebuild once per tick
// instead of once per stream (two rebuilds per cycle with nested StreamBuilders).
class _StatusData {
  const _StatusData({required this.hasNet, required this.btConnected, required this.btEnabled});
  final bool hasNet;
  final bool btConnected;
  final bool btEnabled;
}

class _StatusIcons extends StatefulWidget {
  const _StatusIcons();

  @override
  State<_StatusIcons> createState() => _StatusIconsState();
}

class _StatusIconsState extends State<_StatusIcons> {
  bool _panelOpen = false;
  OverlayEntry? _overlay;

  // Merged stream — updates whenever either source changes, one rebuild total.
  late final Stream<_StatusData> _stream = _buildStream();
  bool _hasNet = false;
  bool _btConnected = false;
  bool _btEnabled = false;

  Stream<_StatusData> _buildStream() {
    final ctrl = StreamController<_StatusData>.broadcast();

    void emit() {
      if (!ctrl.isClosed) {
        ctrl.add(_StatusData(hasNet: _hasNet, btConnected: _btConnected, btEnabled: _btEnabled));
      }
    }

    final sysSub = SystemStatsService.instance.stream.listen((s) {
      _hasNet = s.hasNetwork;
      emit();
    });
    final btSub = BtService.instance.stream.listen((b) {
      _btConnected = b.connected;
      _btEnabled = b.enabled;
      emit();
    });

    ctrl.onCancel = () {
      sysSub.cancel();
      btSub.cancel();
    };

    return ctrl.stream;
  }

  void _togglePanel() => _panelOpen ? _closePanel() : _openPanel();

  void _openPanel() {
    final settings = context.read<SettingsProvider>().settings;
    final renderBox = context.findRenderObject() as RenderBox;
    final iconPos = renderBox.localToGlobal(Offset.zero);
    final iconSize = renderBox.size;
    final sidebarOnLeft = settings.sidebarOnLeft;
    final screenHeight = MediaQuery.of(context).size.height;
    const margin = 12.0;
    final panelMaxHeight = (screenHeight - margin * 2).clamp(0.0, 460.0);
    final topIdeal = iconPos.dy + iconSize.height / 2 - panelMaxHeight / 2;
    final topMax = (screenHeight - panelMaxHeight - margin).clamp(
      margin,
      double.infinity,
    );
    final top = topIdeal.clamp(margin, topMax);

    _overlay = OverlayEntry(
      builder: (_) => _WifiPanelOverlay(
        anchorTop: top,
        maxHeight: panelMaxHeight,
        anchorLeft: sidebarOnLeft ? iconPos.dx + iconSize.width + 20 : null,
        anchorRight: sidebarOnLeft
            ? null
            : MediaQuery.of(context).size.width - iconPos.dx + 20,
        sidebarOnLeft: sidebarOnLeft,
        onClose: _closePanel,
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() => _panelOpen = true);
  }

  void _closePanel() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _panelOpen = false);
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = context.uiScale;
    final iconSz = (13 * scale).clamp(12.0, 18.0);
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final muted = scheme.onSurfaceVariant.withAlpha(100);

    return StreamBuilder<_StatusData>(
      stream: _stream,
      builder: (context, snap) {
        final data = snap.data;
        final hasNet = data?.hasNet ?? false;
        final btConnected = data?.btConnected ?? false;
        final btEnabled = data?.btEnabled ?? false;

        return GestureDetector(
          onTap: _togglePanel,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasNet ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: iconSz,
                  color: _panelOpen
                      ? accent
                      : hasNet
                          ? scheme.onSurface.withAlpha(200)
                          : muted,
                ),
                SizedBox(width: 6 * scale),
                Icon(
                  btConnected
                      ? Icons.bluetooth_connected_rounded
                      : btEnabled
                          ? Icons.bluetooth_rounded
                          : Icons.bluetooth_disabled_rounded,
                  size: iconSz,
                  color: btConnected
                      ? accent
                      : btEnabled
                          ? scheme.onSurface.withAlpha(160)
                          : muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WifiPanelOverlay extends StatelessWidget {
  const _WifiPanelOverlay({
    required this.anchorTop,
    required this.maxHeight,
    required this.sidebarOnLeft,
    required this.onClose,
    this.anchorLeft,
    this.anchorRight,
  });

  final double anchorTop;
  final double maxHeight;
  final double? anchorLeft;
  final double? anchorRight;
  final bool sidebarOnLeft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: anchorTop,
          left: anchorLeft,
          right: anchorRight,
          child: Material(
            type: MaterialType.transparency,
            child: WifiPanel(
              sidebarOnLeft: sidebarOnLeft,
              maxHeight: maxHeight,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

// ── App drawer button ─────────────────────────────────────────────────────────

class _AppDrawerButton extends StatefulWidget {
  const _AppDrawerButton({
    required this.isOnApps,
    required this.accent,
    required this.iconSize,
    required this.onTap,
  });

  final bool isOnApps;
  final Color accent;
  final double iconSize;
  final VoidCallback onTap;

  @override
  State<_AppDrawerButton> createState() => _AppDrawerButtonState();
}

class _AppDrawerButtonState extends State<_AppDrawerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.87,
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
    final accent = widget.accent;
    final isApps = widget.isOnApps;
    final sz = widget.iconSize;
    final radius = sz * 0.28;

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: isApps
                ? accent.withAlpha(220)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            border: Border.all(
              color: isApps
                  ? accent.withAlpha(180)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Center(
            child: _DotsGrid(
              color: isApps
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withAlpha(160),
              size: sz * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsGrid extends StatelessWidget {
  const _DotsGrid({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DotsPainter(color: color)),
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const cols = 3;
    const rows = 3;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    // Dot radius scales with cell size so it's always proportional.
    final r = cellW * 0.18;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(cellW * col + cellW / 2, cellH * row + cellH / 2),
          r,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

// ── Dock slot ─────────────────────────────────────────────────────────────────

class _DockSlot extends StatefulWidget {
  const _DockSlot({
    required this.app,
    required this.iconSize,
    required this.onDrop,
    this.onTap,
    this.onRemove,
  });

  final AppInfo? app;
  final double iconSize;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final ValueChanged<AppInfo> onDrop;

  @override
  State<_DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends State<_DockSlot> with TickerProviderStateMixin {
  late final AnimationController _tapCtrl;
  late final AnimationController _jiggleCtrl;
  bool _hovering = false;
  bool _editing = false;
  OverlayEntry? _barrierEntry;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.84,
      upperBound: 1.0,
      value: 1.0,
    );
    _jiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: -0.04,
      upperBound: 0.04,
    );
  }

  @override
  void dispose() {
    _removeBarrier();
    _tapCtrl.dispose();
    _jiggleCtrl.dispose();
    super.dispose();
  }

  void _enterEditing() {
    setState(() => _editing = true);
    _jiggleCtrl.repeat(reverse: true);
    _barrierEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _exitEditing,
          child: const SizedBox.expand(),
        ),
      ),
    );
    Overlay.of(context).insert(_barrierEntry!);
  }

  void _exitEditing() {
    _removeBarrier();
    if (!mounted) return;
    setState(() => _editing = false);
    _jiggleCtrl.stop();
    _jiggleCtrl.value = 0;
  }

  void _removeBarrier() {
    _barrierEntry?.remove();
    _barrierEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final sz = widget.iconSize;

    return DragTarget<AppInfo>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        _exitEditing();
        widget.onDrop(d.data);
      },
      builder: (context, _, __) {
        if (widget.app == null) {
          final scheme = Theme.of(context).colorScheme;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: sz,
            height: sz,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _hovering ? accent : scheme.outlineVariant,
                width: _hovering ? 2 : 1,
              ),
              color: _hovering
                  ? accent.withAlpha(40)
                  : scheme.surfaceContainerHigh,
            ),
            child: Icon(
              Icons.add_rounded,
              size: sz * 0.38,
              color: _hovering ? accent : scheme.onSurfaceVariant,
            ),
          );
        }

        final iconWidget = AnimatedBuilder(
          animation: _jiggleCtrl,
          builder: (context, child) => Transform.rotate(
            angle: _editing ? _jiggleCtrl.value : 0,
            child: child,
          ),
          child: GestureDetector(
            onTapDown: _editing ? null : (_) => _tapCtrl.reverse(),
            onTapUp: _editing
                ? null
                : (_) {
                    _tapCtrl.forward();
                    widget.onTap?.call();
                  },
            onTapCancel: _editing ? null : () => _tapCtrl.forward(),
            onLongPress: widget.onRemove != null ? _enterEditing : null,
            child: ScaleTransition(
              scale: _tapCtrl,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hovering ? accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: AppIconWidget(app: widget.app!, size: sz),
              ),
            ),
          ),
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            if (_editing)
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _exitEditing();
                    widget.onRemove?.call();
                  },
                  child: Builder(
                    builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      return Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: scheme.onError,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Recent slot ───────────────────────────────────────────────────────────────

class _RecentSlot extends StatefulWidget {
  const _RecentSlot({required this.app, required this.iconSize, this.onTap});
  final AppInfo? app;
  final double iconSize;
  final VoidCallback? onTap;

  @override
  State<_RecentSlot> createState() => _RecentSlotState();
}

class _RecentSlotState extends State<_RecentSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.84,
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
    final sz = widget.iconSize;

    if (widget.app == null) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outlineVariant, width: 1),
          color: scheme.surfaceContainerHigh,
        ),
        child: Icon(
          Icons.history_rounded,
          size: sz * 0.38,
          color: scheme.onSurfaceVariant.withAlpha(140),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconWidget(app: widget.app!, size: sz),
            Positioned(
              bottom: -2,
              right: -2,
              child: Builder(builder: (context) {
                final scheme = Theme.of(context).colorScheme;
                return Container(
                  width: sz * 0.28,
                  height: sz * 0.28,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: scheme.outlineVariant, width: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: sz * 0.16,
                    color: scheme.onSurface.withAlpha(200),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
