import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/background_painter.dart';
import '../pages/app_grid/app_grid_page.dart';
import '../pages/dashboard/dashboard_page.dart';
import '../providers/app_list_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/sidebar/sidebar_widget.dart';
import '../widgets/startup/startup_overlay.dart';

// Sidebar occupies ~10% of screen width, clamped to a usable touch range.
// Computed at build time from MediaQuery so it scales with any screen size.
double _sidebarWidth(BuildContext context) =>
    (MediaQuery.of(context).size.width * 0.10).clamp(68.0, 110.0);

double _sidebarReserved(BuildContext context) => _sidebarWidth(context) + 12.0;

// Page 0 is always the app drawer; dashboard pages follow from index 1.
const int _kDrawerPageIndex = 0;

class LauncherShell extends StatefulWidget {
  const LauncherShell({super.key});

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageCtrl;
  bool _overviewMode = false;
  int _currentPage = 1;
  int _lastDashPage = 1; // remembers which dashboard page to return to

  // Tracks whether the startup sweep has already played this session so we
  // don't replay it when the user just alt-tabs back to the launcher.
  bool _startupPlayed = false;
  // Paused → resumed transition means the screen was off or app was backgrounded.
  AppLifecycleState? _lastLifecycleState;

  int _dashPageCount(SettingsProvider sp) => sp.settings.dashboardPages.length;
  // total pages = 1 drawer + N dashboard pages
  int _totalPages(SettingsProvider sp) => 1 + _dashPageCount(sp);

  bool get _isOnDrawer => _currentPage == _kDrawerPageIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController(initialPage: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppListProvider>().loadApps();
      final sp = context.read<SettingsProvider>();
      // saved dashboard page index → offset by 1 for the drawer page
      final idx = sp.settings.currentDashboardPage + 1;
      if (idx > 1 && _pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(idx);
        setState(() {
          _currentPage = idx;
          _lastDashPage = idx;
        });
      }
      // Play the startup sweep on first launch
      _showStartupOverlay();
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _showStartupOverlay() {
    if (_startupPlayed) return;
    _startupPlayed = true;
    StartupOverlay.show(context, onComplete: () {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns to the launcher (e.g. after closing another app),
    // always land on the dashboard — never leave the drawer open in the background.
    if (state == AppLifecycleState.resumed && _isOnDrawer) {
      if (_pageCtrl.hasClients) {
        _pageCtrl.jumpToPage(_lastDashPage);
      }
      setState(() => _currentPage = _lastDashPage);
    }

    // Play the sweep when resuming from paused (screen-off / backgrounded).
    // We don't replay when coming back from an app the user explicitly opened —
    // the transition paused→resumed is the clearest proxy for "screen turned on".
    if (state == AppLifecycleState.resumed &&
        _lastLifecycleState == AppLifecycleState.paused) {
      _startupPlayed = false; // allow one more play
      _showStartupOverlay();
    }
    _lastLifecycleState = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int page, SettingsProvider sp) {
    setState(() {
      _currentPage = page;
      if (page > 0) _lastDashPage = page;
    });
    if (page > 0) sp.setCurrentDashboardPage(page - 1);
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    if (!_overviewMode && d.scale < 0.82) {
      setState(() => _overviewMode = true);
    }
  }

  void _openAppDrawer() {
    if (!_pageCtrl.hasClients) return;
    if (_isOnDrawer) {
      _pageCtrl.animateToPage(
        _lastDashPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _pageCtrl.animateToPage(
        _kDrawerPageIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final settings = sp.settings;
    final onLeft = settings.sidebarOnLeft;
    final dashCount = _dashPageCount(sp);
    final totalPages = _totalPages(sp);
    // dot index: current page minus 1 (skip drawer page)
    final dotPage = (_currentPage - 1).clamp(0, dashCount - 1);

    return Scaffold(
      backgroundColor: Colors.black,
      body: BackgroundWidget(
        style: settings.backgroundStyle,
        child: GestureDetector(
          onScaleStart: (_) {},
          onScaleUpdate: _handleScaleUpdate,
          behavior: HitTestBehavior.deferToChild,
          child: Stack(
            children: [
              // ── Full PageView: drawer + dashboard pages ────────────────────
              Positioned.fill(
                left: onLeft ? _sidebarReserved(context) : 0,
                right: onLeft ? 0 : _sidebarReserved(context),
                child: PageView.builder(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (p) => _onPageChanged(p, sp),
                  itemCount: totalPages,
                  itemBuilder: (context, index) {
                    if (index == _kDrawerPageIndex) {
                      return RepaintBoundary(
                        key: const ValueKey('app_drawer'),
                        child: _AppDrawerPage(
                          onClose: () => _pageCtrl.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOutCubic,
                          ),
                        ),
                      );
                    }
                    final dashIndex = index - 1;
                    return RepaintBoundary(
                      key: ValueKey('dash_$dashIndex'),
                      child: DashboardPage(pageIndex: dashIndex),
                    );
                  },
                ),
              ),

              // ── Floating sidebar ───────────────────────────────────────────
              Positioned(
                top: 10,
                bottom: 10,
                width: _sidebarWidth(context),
                left: onLeft ? 8 : null,
                right: onLeft ? null : 8,
                child: SidebarWidget(
                  pageController: _pageCtrl,
                  currentPage: _isOnDrawer ? 0 : dotPage + 1,
                  onOpenAppDrawer: _openAppDrawer,
                ),
              ),

              // ── Page dots (dashboard pages only, hidden on drawer) ─────────
              if (dashCount > 1 && !_isOnDrawer)
                Positioned(
                  bottom: 8,
                  left: onLeft ? _sidebarReserved(context) : 0,
                  right: onLeft ? 0 : _sidebarReserved(context),
                  child: _PageDots(
                    currentPage: dotPage,
                    totalPages: dashCount,
                    onTapPage: (i) => _pageCtrl.animateToPage(
                      i + 1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                    ),
                  ),
                ),

              // ── Pinch overview overlay ─────────────────────────────────────
              if (_overviewMode)
                _PageOverview(
                  pageCount: dashCount,
                  currentPage: dotPage,
                  sp: sp,
                  onSelectPage: (i) {
                    setState(() => _overviewMode = false);
                    _pageCtrl.animateToPage(
                      i + 1,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  onAddPage: dashCount < 5
                      ? () {
                          setState(() => _overviewMode = false);
                          _addPage(sp);
                        }
                      : null,
                  onRemovePage: (i) {
                    sp.removeDashboardPage(i);
                    if (sp.settings.dashboardPages.length <= 1) {
                      setState(() => _overviewMode = false);
                    }
                  },
                  onClose: () => setState(() => _overviewMode = false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPage(SettingsProvider sp) {
    sp.addDashboardPage().then((_) {
      final newIdx = sp.settings.dashboardPages.length; // +1 offset for drawer
      _pageCtrl.animateToPage(
        newIdx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }
}

// ── App drawer page (lives inside the PageView) ───────────────────────────────

class _AppDrawerPage extends StatelessWidget {
  const _AppDrawerPage({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AppGridPage();
  }
}

// ── Page dots ─────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.currentPage,
    required this.totalPages,
    required this.onTapPage,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onTapPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (i) {
        final active = i == currentPage;
        return GestureDetector(
          onTap: () => onTapPage(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary
                  : scheme.onSurface.withAlpha(60),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ── Pinch overview ────────────────────────────────────────────────────────────

class _PageOverview extends StatelessWidget {
  const _PageOverview({
    required this.pageCount,
    required this.currentPage,
    required this.sp,
    required this.onSelectPage,
    required this.onAddPage,
    required this.onRemovePage,
    required this.onClose,
  });

  final int pageCount;
  final int currentPage;
  final SettingsProvider sp;
  final ValueChanged<int> onSelectPage;
  final VoidCallback? onAddPage;
  final ValueChanged<int> onRemovePage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onClose,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.scrim.withAlpha(180),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dashboard Pages',
                style: TextStyle(
                  color: scheme.onSurface.withAlpha(200),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(pageCount, (i) {
                    final isActive = i == currentPage;
                    return GestureDetector(
                      onTap: () => onSelectPage(i),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: 90,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? scheme.primaryContainer.withAlpha(200)
                                  : scheme.surfaceContainerHigh.withAlpha(160),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? scheme.primary
                                    : scheme.outline.withAlpha(80),
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Page ${i + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurface.withAlpha(160),
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                          if (pageCount > 1)
                            Positioned(
                              top: -8,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => onRemovePage(i),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: scheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: scheme.onError,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (onAddPage != null)
                    GestureDetector(
                      onTap: onAddPage,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 90,
                        height: 60,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow.withAlpha(140),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.outline.withAlpha(80),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: scheme.onSurface.withAlpha(160),
                          size: 28,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Tap to select  •  Pinch out to dismiss',
                style: TextStyle(
                  color: scheme.onSurface.withAlpha(100),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
