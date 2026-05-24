import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/background_painter.dart';
import '../../../domain/models/launcher_settings.dart';
import '../../providers/settings_provider.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  /// iOS 26-style push: current screen scales down + blurs while settings
  /// slides up from bottom with a spring curve.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      _iOS26Route(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _SettingsScaffold();
  }
}

// ── iOS 26 route ──────────────────────────────────────────────────────────────

class _iOS26Route<T> extends PageRouteBuilder<T> {
  _iOS26Route({required WidgetBuilder builder})
      : super(
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionDuration: const Duration(milliseconds: 480),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          // opaque:false lets the previous route show through during transition
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
            // Sheet slides up from the bottom with a spring feel
            final slideIn = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const _SpringCurve(),
            ));

            // Slight scale-up as it arrives (0.95 → 1.0)
            final scaleIn = Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
            );

            // Progressive dark scrim behind the sheet
            final scrim = Tween<double>(begin: 0.0, end: 0.55).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeIn,
              ),
            );

            return Stack(
              children: [
                // Scrim fades in over the launcher
                FadeTransition(
                  opacity: scrim,
                  child: const ColoredBox(
                    color: Colors.black,
                    child: SizedBox.expand(),
                  ),
                ),
                // Settings sheet slides + scales up
                SlideTransition(
                  position: slideIn,
                  child: ScaleTransition(scale: scaleIn, child: child),
                ),
              ],
            );
          },
        );
}

// Approximates UIKit's spring: fast start, gentle overshoot, quick settle.
class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transform(double t) {
    // Damped spring approximation
    return 1 - (1 - t) * (1 - t) * (1 + 1.8 * t);
  }
}

// ── Scaffold ──────────────────────────────────────────────────────────────────

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold();

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final bg = sp.settings.backgroundStyle;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.transparent,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _BlurredBackground(style: bg),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(),
                    Expanded(child: _SettingsBody()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Blurred wallpaper background ─────────────────────────────────────────────

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.style});
  final BackgroundStyle style;

  @override
  Widget build(BuildContext context) {
    final assetPath = backgroundAssetPath(style);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (assetPath != null)
          Image.asset(assetPath, fit: BoxFit.cover, cacheWidth: 800)
        else
          Container(decoration: gradientDecoration(style)),
        // Heavy blur + dark scrim for legibility
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(color: Colors.black.withAlpha(160)),
        ),
      ],
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _GlassButton(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 2),
                Text('Done',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings body ─────────────────────────────────────────────────────────────

class _SettingsBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [

        // ── Wallpaper ──────────────────────────────────────────────────────
        _SectionLabel('WALLPAPER'),
        _WallpaperPicker(current: s.backgroundStyle),

        // ── Appearance ─────────────────────────────────────────────────────
        _SectionLabel('APPEARANCE'),
        _GlassSection(children: [
          _SwitchRow(
            icon: Icons.dark_mode_rounded,
            iconColor: const Color(0xFF5E5CE6),
            label: 'Dark Mode',
            value: s.isDarkMode,
            onChanged: (_) => sp.toggleTheme(),
          ),
          _Hairline(),
          _SwitchRow(
            icon: Icons.label_outline_rounded,
            iconColor: const Color(0xFF30D158),
            label: 'App Labels',
            value: s.showAppLabels,
            onChanged: (_) => sp.toggleAppLabels(),
          ),
          _Hairline(),
          _SwitchRow(
            icon: Icons.swap_horiz_rounded,
            iconColor: const Color(0xFF0A84FF),
            label: 'Sidebar on Left',
            value: s.sidebarOnLeft,
            onChanged: (_) => sp.toggleSidebarSide(),
          ),
        ]),

        // ── Display Scale ──────────────────────────────────────────────────
        _SectionLabel('DISPLAY SCALE'),
        _GlassSection(children: [
          _ScaleRow(current: s.uiScale),
        ]),

        // ── Accent Color ───────────────────────────────────────────────────
        _SectionLabel('ACCENT COLOR'),
        _GlassSection(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: _AccentPicker(current: s.accentColor),
          ),
        ]),

        // ── Speed ──────────────────────────────────────────────────────────
        _SectionLabel('SPEED'),
        _GlassSection(children: [
          _SegmentRow(
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFFFF3B30),
            label: 'Speed Limit',
            options: const ['50', '60', '80', '100', '120'],
            selected: s.speedLimitKmh.toString(),
            onSelected: (v) => sp.setSpeedLimit(int.parse(v)),
          ),
        ]),

        // ── App Grid ───────────────────────────────────────────────────────
        _SectionLabel('APP GRID'),
        _GlassSection(children: [
          _SliderRow(
            icon: Icons.apps_rounded,
            iconColor: const Color(0xFFFF9F0A),
            label: 'Icon Size',
            value: s.appIconSize,
            min: 80,
            max: 130,
            divisions: 10,
            onChanged: sp.setIconSize,
          ),
          _Hairline(),
          _SegmentRow(
            icon: Icons.grid_view_rounded,
            iconColor: const Color(0xFF5AC8FA),
            label: 'Columns',
            options: const ['4', '5', '6'],
            selected: s.gridColumns.toString(),
            onSelected: (v) => sp.setGridColumns(int.parse(v)),
          ),
        ]),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Wallpaper picker ──────────────────────────────────────────────────────────

class _WallpaperPicker extends StatelessWidget {
  const _WallpaperPicker({required this.current});
  final BackgroundStyle current;

  static const _photos = [
    (BackgroundStyle.photo1, 'assets/backgrounds/1.jpg', 'Scene 1'),
    (BackgroundStyle.photo2, 'assets/backgrounds/2.jpg', 'Scene 2'),
    (BackgroundStyle.photo3, 'assets/backgrounds/3.jpg', 'Scene 3'),
    (BackgroundStyle.photo4, 'assets/backgrounds/4.jpg', 'Scene 4'),
    (BackgroundStyle.photo5, 'assets/backgrounds/5.jpg', 'Scene 5'),
    (BackgroundStyle.photo6, 'assets/backgrounds/7.jpg', 'Scene 6'),
  ];

  static const _gradients = [
    (BackgroundStyle.darkGradient, 'Dark',
        [Color(0xFF0A0A10), Color(0xFF12121C)]),
    (BackgroundStyle.blueGradient, 'Blue',
        [Color(0xFF03080F), Color(0xFF071528)]),
    (BackgroundStyle.purpleGradient, 'Purple',
        [Color(0xFF08040F), Color(0xFF140920)]),
    (BackgroundStyle.solidDark, 'Solid',
        [Color(0xFF09090B), Color(0xFF1A1A1E)]),
    (BackgroundStyle.solidLight, 'Light',
        [Color(0xFFEEF0F6), Color(0xFFD8DCE8)]),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SettingsProvider>();
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo grid
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: _photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (style, path, label) = _photos[i];
              final selected = current == style;
              return GestureDetector(
                onTap: () => sp.setBackground(style),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? accent : Colors.white.withAlpha(30),
                      width: selected ? 2.5 : 0.5,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(
                            color: accent.withAlpha(80), blurRadius: 12)]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(path, fit: BoxFit.cover, cacheWidth: 240),
                        if (selected)
                          Container(
                            color: accent.withAlpha(40),
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Gradient chips — LayoutBuilder provides finite width so chips
        // can be divided evenly without Expanded inside an unbounded ListView.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final chipW =
                (constraints.maxWidth - gap * (_gradients.length - 1)) /
                _gradients.length;
            return Row(
              children: _gradients.map((item) {
                final (style, label, colors) = item;
                final selected = current == style;
                return GestureDetector(
                  onTap: () => sp.setBackground(style),
                  child: Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: chipW,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: colors,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? accent
                                  : Colors.white.withAlpha(25),
                              width: selected ? 2 : 0.5,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                        color: accent.withAlpha(70),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  color: colors[0].computeLuminance() > 0.4
                                      ? Colors.black54
                                      : Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? Colors.white
                                : Colors.white.withAlpha(100),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Accent color picker ───────────────────────────────────────────────────────

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.current});
  final AccentColor current;

  static const _items = [
    (AccentColor.blue,   Color(0xFF0A84FF), 'Blue'),
    (AccentColor.green,  Color(0xFF30D158), 'Green'),
    (AccentColor.orange, Color(0xFFFF9F0A), 'Orange'),
    (AccentColor.red,    Color(0xFFFF453A), 'Red'),
    (AccentColor.purple, Color(0xFFBF5AF2), 'Purple'),
    (AccentColor.teal,   Color(0xFF5AC8FA), 'Teal'),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SettingsProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _items.map((item) {
        final (accent, color, label) = item;
        final selected = accent == current;
        return GestureDetector(
          onTap: () => sp.setAccentColor(accent),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(
                          color: color.withAlpha(160),
                          blurRadius: 12,
                          spreadRadius: 1)]
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color:
                      selected ? Colors.white : Colors.white.withAlpha(100),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Reusable section primitives ───────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8, top: 24),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withAlpha(120),
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.white.withAlpha(30), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
}

class _Hairline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Divider(
            color: Colors.white.withAlpha(18), height: 0.5, thickness: 0.5),
      );
}

// ── Row widgets ───────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    height: 2.8)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: accent,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatefulWidget {
  const _SliderRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState extends State<_SliderRow> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(_SliderRow old) {
    super.didUpdateWidget(old);
    // Sync from provider only when not dragging (i.e. value changed externally)
    if (old.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final displayValue = '${_localValue.toInt()}px';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              _IconBadge(icon: widget.icon, color: widget.iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white.withAlpha(30),
              thumbColor: Colors.white,
              overlayColor: accent.withAlpha(30),
            ),
            child: Slider(
              value: _localValue,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) => setState(() => _localValue = v),
              onChangeEnd: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: options.map((opt) {
                final isSelected = opt == selected;
                return GestureDetector(
                  onTap: () => onSelected(opt),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: accent.withAlpha(70), blurRadius: 6)]
                          : null,
                    ),
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withAlpha(100),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Display scale picker ──────────────────────────────────────────────────────

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({required this.current});
  final double current;

  static const _options = [
    (0.0,  'Auto'),
    (0.85, '85%'),
    (1.0,  '100%'),
    (1.15, '115%'),
    (1.3,  '130%'),
  ];

  @override
  Widget build(BuildContext context) {
    final sp = context.read<SettingsProvider>();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _IconBadge(icon: Icons.display_settings_rounded, color: const Color(0xFF5E5CE6)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('UI Scale', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _options.map((opt) {
                final (value, label) = opt;
                final isSelected = current == value;
                return GestureDetector(
                  onTap: () => sp.setUiScale(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [BoxShadow(color: accent.withAlpha(70), blurRadius: 6)]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.white.withAlpha(100),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      );
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 80),
        lowerBound: 0.92,
        upperBound: 1.0,
        value: 1.0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withAlpha(40), width: 0.5),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
