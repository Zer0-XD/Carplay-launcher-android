import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../shell/launcher_shell.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

enum _PermId { location, notifications, bluetooth }

class _PermItem {
  const _PermItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.required,
  });

  final _PermId id;
  final IconData icon;
  final String title;
  final String description;
  final bool required;
}

const _items = [
  _PermItem(
    id: _PermId.location,
    icon: Icons.location_on_rounded,
    title: 'Location',
    description: 'Used for GPS speed and navigation.',
    required: true,
  ),
  _PermItem(
    id: _PermId.notifications,
    icon: Icons.music_note_rounded,
    title: 'Notification Access',
    description: 'Enables media playback info from other apps.',
    required: false,
  ),
  _PermItem(
    id: _PermId.bluetooth,
    icon: Icons.bluetooth_rounded,
    title: 'Bluetooth',
    description: 'Shows connected device info in the sidebar.',
    required: false,
  ),
];

// ── Channels ──────────────────────────────────────────────────────────────────

const _mediaChannel = MethodChannel('com.zero.dashflow_launcher/media');
const _sysChannel   = MethodChannel('com.zero.dashflow_launcher/system');

// ── Gate widget ───────────────────────────────────────────────────────────────

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _allDone  = false;

  final Map<_PermId, bool> _granted = {
    for (final p in _items) p.id: false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay first check by one frame so method channels are fully registered
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_allDone) _checkAll();
  }

  Future<void> _checkAll() async {
    setState(() => _checking = true);

    final results = await Future.wait([
      _checkLocation(),
      _checkNotificationListener(),
      _checkBluetooth(),
    ]);

    final updated = {
      _PermId.location:      results[0],
      _PermId.notifications: results[1],
      _PermId.bluetooth:     results[2],
    };

    final requiredDone = _items
        .where((p) => p.required)
        .every((p) => updated[p.id] == true);

    if (mounted) {
      setState(() {
        _granted.addAll(updated);
        _checking = false;
        _allDone  = requiredDone;
      });
    }
  }

  Future<bool> _checkLocation() async {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> _checkNotificationListener() async {
    try {
      return await _mediaChannel
              .invokeMethod<bool>('isNotificationListenerGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkBluetooth() async {
    try {
      return await _sysChannel
              .invokeMethod<bool>('isBluetoothPermissionGranted') ??
          false;
    } catch (_) {
      // Channel not implemented yet → treat as granted so it doesn't block
      return true;
    }
  }

  Future<void> _request(_PermId id) async {
    switch (id) {
      case _PermId.location:
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        } else {
          await Geolocator.requestPermission();
        }

      case _PermId.notifications:
        try {
          await _mediaChannel.invokeMethod('openNotificationListenerSettings');
        } catch (_) {}

      case _PermId.bluetooth:
        try {
          await _sysChannel.invokeMethod('requestBluetoothPermission');
        } catch (_) {
          await Geolocator.openAppSettings();
        }
    }
    await _checkAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const _SplashScreen();
    if (_allDone)  return const LauncherShell();
    return _SetupScreen(
      items: _items,
      granted: _granted,
      onRequest: _request,
      onRefresh: _checkAll,
      onContinue: _checkAll,
    );
  }
}

// ── Splash ────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF0A0A10),
        body: Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(0xFF0A84FF)),
          ),
        ),
      );
}

// ── Setup screen ──────────────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen({
    required this.items,
    required this.granted,
    required this.onRequest,
    required this.onRefresh,
    required this.onContinue,
  });

  final List<_PermItem> items;
  final Map<_PermId, bool> granted;
  final Future<void> Function(_PermId) onRequest;
  final VoidCallback onRefresh;
  final VoidCallback onContinue;

  bool get _requiredDone =>
      items.where((p) => p.required).every((p) => granted[p.id] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF0A84FF).withAlpha(80)),
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Color(0xFF0A84FF), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Permissions Required',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Grant access to enable all features',
                          style: TextStyle(
                              color: Colors.white.withAlpha(100), fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onRefresh,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.refresh_rounded,
                            color: Colors.white.withAlpha(160), size: 20),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Permission rows ───────────────────────────────────────────
                ...items.map((item) => _PermRow(
                      item: item,
                      isGranted: granted[item.id] ?? false,
                      onTap: () => onRequest(item.id),
                    )),

                const SizedBox(height: 28),

                // ── Continue ──────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: _ContinueButton(
                      enabled: _requiredDone, onTap: onContinue),
                ),

                if (!_requiredDone) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Required permissions must be granted to continue',
                      style: TextStyle(
                          color: Colors.white.withAlpha(60), fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Permission row ────────────────────────────────────────────────────────────

class _PermRow extends StatelessWidget {
  const _PermRow(
      {required this.item, required this.isGranted, required this.onTap});

  final _PermItem item;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const blue  = Color(0xFF0A84FF);
    const green = Color(0xFF30D158);
    final color = isGranted ? green : (item.required ? blue : Colors.white);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isGranted ? green.withAlpha(12) : Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted ? green.withAlpha(60) : Colors.white.withAlpha(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (!item.required) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Optional',
                                style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.description,
                        style: TextStyle(
                            color: Colors.white.withAlpha(90),
                            fontSize: 11,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Status / button
              if (isGranted)
                const Icon(Icons.check_circle_rounded, color: green, size: 22)
              else
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: blue.withAlpha(200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.id == _PermId.notifications
                          ? 'Open Settings'
                          : 'Allow',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
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

// ── Continue button ───────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xFF0A84FF)
                : const Color(0xFF0A84FF).withAlpha(50),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            'Continue',
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white.withAlpha(80),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
