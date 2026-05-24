import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/services/quick_controls_service.dart';
import '../../../data/services/wifi_service.dart';
import 'base_card.dart';

class QuickControlsCard extends StatefulWidget {
  const QuickControlsCard({
    super.key,
    this.isEditing = false,
    this.onLongPress,
    this.isLarge = false,
  });

  final bool isEditing;
  final VoidCallback? onLongPress;
  final bool isLarge;

  @override
  State<QuickControlsCard> createState() => _QuickControlsCardState();
}

class _QuickControlsCardState extends State<QuickControlsCard> {
  final _svc = QuickControlsService.instance;
  final _wifiSvc = WifiService.instance;

  VolumeInfo _vol = const VolumeInfo(current: 8, max: 15);
  int _brightness = 128;
  WifiStatus _wifiStatus = WifiStatus.disconnected;
  bool _wifiEnabled = false;
  bool _btEnabled = false;
  bool _btConnected = false;

  Timer? _pollTimer;
  Timer? _volDebounce;
  bool _draggingVol = false;
  bool _draggingBright = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_draggingVol && !_draggingBright) _refresh();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _volDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final vol = await _svc.getVolume();
    final bright = await _svc.getBrightness();
    final wifi = await _svc.getWifiEnabled();
    final bt = await _svc.getBluetoothEnabled();
    final wifiStatus = await _wifiSvc.getStatus();
    if (mounted) {
      setState(() {
        _vol = vol;
        _brightness = bright;
        _wifiEnabled = wifi;
        _wifiStatus = wifiStatus;
        _btEnabled = bt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      isEditing: widget.isEditing,
      onLongPress: widget.onLongPress,
      padding: EdgeInsets.zero,
      accentColor: const Color(0xFF14B8A6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = (constraints.smallest.shortestSide / 200.0).clamp(0.5, 2.0);
          final wide = constraints.maxWidth > constraints.maxHeight * 1.3;
          return wide
              ? _WideLayout(
                  vol: _vol, brightness: _brightness,
                  wifiEnabled: _wifiEnabled, wifiStatus: _wifiStatus,
                  btEnabled: _btEnabled, btConnected: _btConnected,
                  s: s,
                  onVolChange: _onVolChange,
                  onVolDragStart: () => _draggingVol = true,
                  onVolDragEnd: () => _draggingVol = false,
                  onBrightChange: _onBrightChange,
                  onBrightDragStart: () => _draggingBright = true,
                  onBrightDragEnd: () => _draggingBright = false,
                  onToggleWifi: _toggleWifi,
                  onToggleBt: _toggleBt,
                )
              : _CompactLayout(
                  vol: _vol,
                  wifiEnabled: _wifiEnabled, wifiStatus: _wifiStatus,
                  btEnabled: _btEnabled, btConnected: _btConnected,
                  s: s,
                  onVolChange: _onVolChange,
                  onVolDragStart: () => _draggingVol = true,
                  onVolDragEnd: () => _draggingVol = false,
                  onToggleWifi: _toggleWifi,
                  onToggleBt: _toggleBt,
                );
        },
      ),
    );
  }

  void _onVolChange(double v) {
    final next = (v * _vol.max).round().clamp(0, _vol.max);
    setState(() => _vol = VolumeInfo(current: next, max: _vol.max));
    _volDebounce?.cancel();
    _volDebounce = Timer(const Duration(milliseconds: 80), () => _svc.setVolume(next));
  }

  void _onBrightChange(double v) {
    final next = (v * 255).round().clamp(0, 255);
    setState(() => _brightness = next);
    _svc.setBrightness(next);
  }

  Future<void> _toggleWifi() async {
    await _svc.setWifiEnabled(!_wifiEnabled);
    final enabled = await _svc.getWifiEnabled();
    if (mounted) setState(() => _wifiEnabled = enabled);
  }

  Future<void> _toggleBt() async {
    await _svc.setBluetoothEnabled(!_btEnabled);
    final enabled = await _svc.getBluetoothEnabled();
    if (mounted) setState(() => _btEnabled = enabled);
  }
}

// ── Compact: volume + 2 tiles ─────────────────────────────────────────────────

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.vol, required this.wifiEnabled, required this.wifiStatus,
    required this.btEnabled, required this.btConnected, required this.s,
    required this.onVolChange, required this.onVolDragStart,
    required this.onVolDragEnd, required this.onToggleWifi, required this.onToggleBt,
  });

  final VolumeInfo vol;
  final bool wifiEnabled;
  final WifiStatus wifiStatus;
  final bool btEnabled;
  final bool btConnected;
  final double s;
  final ValueChanged<double> onVolChange;
  final VoidCallback onVolDragStart, onVolDragEnd, onToggleWifi, onToggleBt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: 'CONTROLS', s: s),
          SizedBox(height: 8 * s),
          Expanded(
            flex: 4,
            child: Center(
              child: _SliderRow(
                icon: Icons.volume_up_rounded,
                value: vol.fraction,
                s: s,
                onChanged: onVolChange,
                onDragStart: onVolDragStart,
                onDragEnd: onVolDragEnd,
              ),
            ),
          ),
          SizedBox(height: 8 * s),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(child: _Tile(
                  icon: _wifiIcon(wifiEnabled, wifiStatus),
                  label: wifiEnabled && wifiStatus.connected
                      ? _shortSsid(wifiStatus.ssid) : 'WiFi',
                  active: wifiEnabled,
                  s: s, onTap: onToggleWifi,
                )),
                SizedBox(width: 8 * s),
                Expanded(child: _Tile(
                  icon: btConnected ? Icons.bluetooth_connected_rounded
                      : btEnabled ? Icons.bluetooth_rounded
                      : Icons.bluetooth_disabled_rounded,
                  label: 'BT',
                  active: btEnabled,
                  s: s, onTap: onToggleBt,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wide: header + 2 sliders + 3 tiles ───────────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.vol, required this.brightness, required this.wifiEnabled,
    required this.wifiStatus, required this.btEnabled, required this.btConnected,
    required this.s,
    required this.onVolChange, required this.onVolDragStart, required this.onVolDragEnd,
    required this.onBrightChange, required this.onBrightDragStart, required this.onBrightDragEnd,
    required this.onToggleWifi, required this.onToggleBt,
  });

  final VolumeInfo vol;
  final int brightness;
  final bool wifiEnabled;
  final WifiStatus wifiStatus;
  final bool btEnabled;
  final bool btConnected;
  final double s;
  final ValueChanged<double> onVolChange, onBrightChange;
  final VoidCallback onVolDragStart, onVolDragEnd,
      onBrightDragStart, onBrightDragEnd, onToggleWifi, onToggleBt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(14 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(text: 'QUICK CONTROLS', s: s),
          SizedBox(height: 10 * s),
          Expanded(
            flex: 4,
            child: Center(
              child: _SliderRow(
                icon: Icons.volume_up_rounded,
                value: vol.fraction,
                label: 'Volume',
                s: s,
                onChanged: onVolChange,
                onDragStart: onVolDragStart,
                onDragEnd: onVolDragEnd,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: _SliderRow(
                icon: Icons.brightness_6_rounded,
                value: brightness / 255,
                label: 'Bright',
                s: s,
                onChanged: onBrightChange,
                onDragStart: onBrightDragStart,
                onDragEnd: onBrightDragEnd,
              ),
            ),
          ),
          SizedBox(height: 8 * s),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(child: _Tile(
                  icon: _wifiIcon(wifiEnabled, wifiStatus),
                  label: wifiEnabled && wifiStatus.connected
                      ? _shortSsid(wifiStatus.ssid) : 'WiFi',
                  active: wifiEnabled, s: s, onTap: onToggleWifi,
                )),
                SizedBox(width: 8 * s),
                Expanded(child: _Tile(
                  icon: btConnected ? Icons.bluetooth_connected_rounded
                      : btEnabled ? Icons.bluetooth_rounded
                      : Icons.bluetooth_disabled_rounded,
                  label: 'BT', active: btEnabled, s: s, onTap: onToggleBt,
                )),
                SizedBox(width: 8 * s),
                Expanded(child: _Tile(
                  icon: Icons.do_not_disturb_on_rounded,
                  label: 'DnD', active: false, s: s, onTap: () {},
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

IconData _wifiIcon(bool enabled, WifiStatus status) {
  if (!enabled) return Icons.wifi_off_rounded;
  if (!status.connected) return Icons.wifi_rounded;
  if (status.bars <= 1) return Icons.wifi_1_bar_rounded;
  if (status.bars == 2) return Icons.wifi_2_bar_rounded;
  return Icons.wifi_rounded;
}

String _shortSsid(String ssid) =>
    ssid.length > 8 ? '${ssid.substring(0, 7)}…' : ssid;

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.s});
  final String text;
  final double s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 2.5,
          height: 10 * s,
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6 * s),
        Text(
          text,
          style: TextStyle(
            fontSize: 8 * s, fontWeight: FontWeight.w700,
            letterSpacing: 1.8, color: scheme.onSurface.withAlpha(120),
          ),
        ),
      ],
    );
  }
}

// ── Slider row ────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon, required this.value, required this.s,
    required this.onChanged, required this.onDragStart, required this.onDragEnd,
    this.label,
  });

  final IconData icon;
  final double value;
  final double s;
  final ValueChanged<double> onChanged;
  final VoidCallback onDragStart, onDragEnd;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14 * s, color: const Color(0xFF14B8A6).withAlpha(200)),
        SizedBox(width: 6 * s),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: const Color(0xFF14B8A6),
              inactiveTrackColor: scheme.surfaceContainerHigh,
              thumbColor: scheme.onSurface,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5 * s),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 12 * s),
              overlayColor: const Color(0xFF14B8A6).withAlpha(28),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChangeStart: (_) => onDragStart(),
              onChanged: onChanged,
              onChangeEnd: (_) => onDragEnd(),
            ),
          ),
        ),
        SizedBox(
          width: 30 * s,
          child: Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              fontSize: 9 * s, color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon, required this.label,
    required this.active, required this.s, required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final double s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF14B8A6);
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accent.withAlpha(120) : scheme.outlineVariant.withAlpha(100),
            width: active ? 1.0 : 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18 * s,
                color: active ? accent : scheme.onSurfaceVariant),
            SizedBox(height: 4 * s),
            Text(
              label,
              style: TextStyle(
                fontSize: 9 * s, fontWeight: FontWeight.w600,
                color: active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
