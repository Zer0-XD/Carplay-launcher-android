import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../data/services/wifi_service.dart';

class WifiPanel extends StatefulWidget {
  const WifiPanel({
    super.key,
    required this.sidebarOnLeft,
    required this.onClose,
    this.maxHeight = 460,
  });

  final bool sidebarOnLeft;
  final VoidCallback onClose;
  final double maxHeight;

  @override
  State<WifiPanel> createState() => _WifiPanelState();
}

class _WifiPanelState extends State<WifiPanel>
    with SingleTickerProviderStateMixin {
  final _wifi = WifiService.instance;

  List<WifiNetwork> _networks = [];
  WifiStatus _status = WifiStatus.disconnected;
  bool _scanning = false;
  String? _connecting;
  Timer? _autoScanTimer;
  Timer? _statusTimer;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slideAnim = Tween<Offset>(
      begin: widget.sidebarOnLeft
          ? const Offset(-0.06, 0)
          : const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
    _initData();
  }

  Future<void> _initData() async {
    await _refreshStatus();
    await _doScan();
    _startTimers();
  }

  void _startTimers() {
    _statusTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refreshStatus());
    if (!_status.connected) _startAutoScan();
  }

  void _startAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer =
        Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_status.connected) await _doScan();
    });
  }

  void _stopAutoScan() {
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
  }

  Future<void> _refreshStatus() async {
    final s = await _wifi.getStatus();
    if (!mounted) return;
    final wasConnected = _status.connected;
    setState(() => _status = s);
    if (!wasConnected && s.connected) {
      _stopAutoScan();
      await _doScan();
    } else if (wasConnected && !s.connected) {
      _startAutoScan();
      await _doScan();
    }
  }

  Future<void> _doScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    final nets = await _wifi.scan();
    if (!mounted) return;
    setState(() {
      _networks = nets;
      _scanning = false;
    });
  }

  Future<void> _connect(WifiNetwork net) async {
    if (net.secured) {
      final pw = await _showPasswordDialog(net.ssid);
      if (pw == null) return;
      setState(() => _connecting = net.ssid);
      await _wifi.connect(net.ssid, password: pw);
    } else {
      setState(() => _connecting = net.ssid);
      await _wifi.connect(net.ssid);
    }
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _connecting = null);
    await _refreshStatus();
    await _doScan();
  }

  Future<void> _disconnect() async {
    await _wifi.disconnect();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await _refreshStatus();
    await _doScan();
    _startAutoScan();
  }

  Future<String?> _showPasswordDialog(String ssid) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PasswordDialog(ssid: ssid, ctrl: ctrl),
    );
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _statusTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Separate connected network from the rest in the list
    final connectedSsid = _status.connected ? _status.ssid : null;
    final others = _networks
        .where((n) => n.ssid != connectedSsid)
        .toList();

    return FadeTransition(
      opacity: _slideCtrl,
      child: SlideTransition(
        position: _slideAnim,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              width: 260,
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withAlpha(220),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withAlpha(18),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(140),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title bar
                  _TitleBar(
                    scanning: _scanning,
                    connected: _status.connected,
                    onRefresh: _doScan,
                    onClose: widget.onClose,
                  ),

                  // ── Connected card (always visible when connected)
                  if (_status.connected) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: _ConnectedCard(
                        status: _status,
                        onDisconnect: _disconnect,
                      ),
                    ),
                  ],

                  // ── Nearby networks label
                  if (others.isNotEmpty || (!_status.connected && _networks.isEmpty))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        _status.connected ? 'OTHER NETWORKS' : 'AVAILABLE NETWORKS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: Colors.white.withAlpha(80),
                        ),
                      ),
                    ),

                  // ── Network list
                  Flexible(
                    child: _NetworkList(
                      networks: others,
                      connecting: _connecting,
                      scanning: _scanning && _networks.isEmpty,
                      onConnect: _connect,
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Title bar ─────────────────────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.scanning,
    required this.connected,
    required this.onRefresh,
    required this.onClose,
  });

  final bool scanning;
  final bool connected;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF0A84FF).withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wifi_rounded,
                size: 16, color: Color(0xFF0A84FF)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Wi-Fi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          // Scanning indicator or refresh button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: scanning
                ? SizedBox(
                    key: const ValueKey('spin'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white.withAlpha(120),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('refresh'),
                    onTap: onRefresh,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 16, color: Colors.white.withAlpha(160)),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close_rounded,
                  size: 16, color: Colors.white.withAlpha(120)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Connected card ────────────────────────────────────────────────────────────

class _ConnectedCard extends StatelessWidget {
  const _ConnectedCard({required this.status, required this.onDisconnect});

  final WifiStatus status;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A84FF).withAlpha(35),
            const Color(0xFF0A84FF).withAlpha(18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0A84FF).withAlpha(70),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Signal arc icon
              _WifiArc(bars: status.bars, color: const Color(0xFF0A84FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.ssid,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF30D158),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Connected  •  ${status.rssi} dBm',
                          style: TextStyle(
                            color: Colors.white.withAlpha(160),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Disconnect pill
              GestureDetector(
                onTap: onDisconnect,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF453A).withAlpha(60),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Disconnect',
                    style: TextStyle(
                      color: Color(0xFFFF453A),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Traffic row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TrafficCell(
                    icon: Icons.arrow_upward_rounded,
                    label: 'Upload',
                    value: _fmtRate(status.txKbps),
                    color: const Color(0xFF30D158),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 28,
                  color: Colors.white.withAlpha(20),
                ),
                Expanded(
                  child: _TrafficCell(
                    icon: Icons.arrow_downward_rounded,
                    label: 'Download',
                    value: _fmtRate(status.rxKbps),
                    color: const Color(0xFF0A84FF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtRate(double kbps) {
    if (kbps >= 1024) return '${(kbps / 1024).toStringAsFixed(1)} MB/s';
    return '${kbps.toStringAsFixed(0)} KB/s';
  }
}

class _TrafficCell extends StatelessWidget {
  const _TrafficCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Network list ──────────────────────────────────────────────────────────────

class _NetworkList extends StatelessWidget {
  const _NetworkList({
    required this.networks,
    required this.onConnect,
    required this.scanning,
    this.connecting,
  });

  final List<WifiNetwork> networks;
  final String? connecting;
  final bool scanning;
  final ValueChanged<WifiNetwork> onConnect;

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white.withAlpha(100),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Scanning…',
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (networks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: Text(
            'No networks found',
            style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 11),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: networks.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 38,
        color: Colors.white.withAlpha(12),
      ),
      itemBuilder: (_, i) {
        final net = networks[i];
        final isConnecting = connecting == net.ssid;
        return _NetworkTile(
          net: net,
          isConnecting: isConnecting,
          onTap: () => onConnect(net),
        );
      },
    );
  }
}

class _NetworkTile extends StatefulWidget {
  const _NetworkTile({
    required this.net,
    required this.isConnecting,
    required this.onTap,
  });
  final WifiNetwork net;
  final bool isConnecting;
  final VoidCallback onTap;

  @override
  State<_NetworkTile> createState() => _NetworkTileState();
}

class _NetworkTileState extends State<_NetworkTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          color: _pressed ? Colors.white.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _WifiArc(
              bars: widget.net.bars,
              color: Colors.white.withAlpha(180),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.net.ssid,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isConnecting)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white.withAlpha(140),
                ),
              )
            else ...[
              if (widget.net.secured)
                Icon(Icons.lock_rounded,
                    size: 12, color: Colors.white.withAlpha(60)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.white.withAlpha(40)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Password dialog ───────────────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.ssid, required this.ctrl});
  final String ssid;
  final TextEditingController ctrl;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E).withAlpha(230),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(18), width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A84FF).withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.wifi_password_rounded,
                          size: 18, color: Color(0xFF0A84FF)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enter Password',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            widget.ssid,
                            style: TextStyle(
                                color: Colors.white.withAlpha(120),
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.ctrl,
                  obscureText: _obscure,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle:
                        TextStyle(color: Colors.white.withAlpha(60), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withAlpha(12),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: const Color(0xFF0A84FF).withAlpha(180),
                          width: 1),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18,
                        color: Colors.white.withAlpha(80),
                      ),
                    ),
                  ),
                  onSubmitted: (v) => Navigator.of(context).pop(v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors.white.withAlpha(160),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(widget.ctrl.text),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A84FF).withAlpha(200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Connect',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── WiFi arc icon (proper sector arcs like iOS) ───────────────────────────────

class _WifiArc extends StatelessWidget {
  const _WifiArc({
    required this.bars,
    required this.color,
    this.size = 20,
  });
  final int bars;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WifiArcPainter(bars: bars, color: color)),
    );
  }
}

class _WifiArcPainter extends CustomPainter {
  const _WifiArcPainter({required this.bars, required this.color});
  final int bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.78;
    const totalArcs = 3;
    const startAngle = -200 * (3.14159 / 180.0);
    const sweepAngle = 200 * (3.14159 / 180.0) * -1;

    // Dot at bottom
    final dotPaint = Paint()
      ..color = bars > 0 ? color : color.withAlpha(50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size.width * 0.07, dotPaint);

    // Three arcs
    for (var i = 0; i < totalArcs; i++) {
      final radius = size.width * (0.22 + i * 0.22);
      final active = (i + 1) <= bars;
      final paint = Paint()
        ..color = active ? color : color.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.085
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WifiArcPainter old) =>
      old.bars != bars || old.color != color;
}
