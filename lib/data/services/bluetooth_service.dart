import 'dart:async';
import 'package:flutter/services.dart';

class BluetoothDevice {
  const BluetoothDevice({required this.name, required this.address, required this.type});
  final String name;
  final String address;
  final int type; // 1=classic, 2=LE, 3=dual
}

class BluetoothStatus {
  const BluetoothStatus({
    required this.enabled,
    required this.connected,
    required this.devices,
  });

  final bool enabled;
  final bool connected;
  final List<BluetoothDevice> devices;

  static const off = BluetoothStatus(enabled: false, connected: false, devices: []);
}

class BtService {
  BtService._();
  static final BtService instance = BtService._();

  static const _channel = MethodChannel('com.zero.dashflow_launcher/bluetooth');

  late final Stream<BluetoothStatus> stream = _build();

  Stream<BluetoothStatus> _build() {
    late StreamController<BluetoothStatus> ctrl;
    Timer? timer;
    ctrl = StreamController<BluetoothStatus>.broadcast(
      onListen: () async {
        ctrl.add(await _poll());
        timer = Timer.periodic(const Duration(seconds: 3), (_) async {
          if (!ctrl.hasListener) return;
          ctrl.add(await _poll());
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return ctrl.stream;
  }

  Future<BluetoothStatus> _poll() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBluetoothStatus');
      if (raw == null) return BluetoothStatus.off;
      final devList = (raw['devices'] as List<dynamic>? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return BluetoothDevice(
          name: m['name'] as String? ?? 'Unknown',
          address: m['address'] as String? ?? '',
          type: (m['type'] as num?)?.toInt() ?? 1,
        );
      }).toList();
      return BluetoothStatus(
        enabled: raw['enabled'] as bool? ?? false,
        connected: raw['connected'] as bool? ?? false,
        devices: devList,
      );
    } on MissingPluginException {
      return BluetoothStatus.off;
    } catch (_) {
      return BluetoothStatus.off;
    }
  }
}
