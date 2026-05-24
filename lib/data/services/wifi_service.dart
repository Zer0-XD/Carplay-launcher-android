import 'dart:async';
import 'package:flutter/services.dart';

class WifiNetwork {
  const WifiNetwork({
    required this.ssid,
    required this.level,
    required this.bars,
    required this.secured,
    required this.connected,
  });

  final String ssid;
  final int level;   // dBm
  final int bars;    // 0-3
  final bool secured;
  final bool connected;
}

class WifiStatus {
  const WifiStatus({
    required this.connected,
    required this.ssid,
    required this.txKbps,
    required this.rxKbps,
    required this.bars,
    required this.rssi,
  });

  final bool connected;
  final String ssid;
  final double txKbps;
  final double rxKbps;
  final int bars;
  final int rssi;

  static const disconnected = WifiStatus(
    connected: false, ssid: '', txKbps: 0, rxKbps: 0, bars: 0, rssi: 0,
  );
}

class WifiService {
  WifiService._();
  static final WifiService instance = WifiService._();

  static const _channel = MethodChannel('com.zero.dashflow_launcher/wifi');

  Future<List<WifiNetwork>> scan() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('scanWifi');
      if (raw == null) return [];
      return raw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return WifiNetwork(
          ssid: m['ssid'] as String? ?? '',
          level: (m['level'] as num?)?.toInt() ?? 0,
          bars: (m['bars'] as num?)?.toInt() ?? 0,
          secured: m['secured'] as bool? ?? false,
          connected: m['connected'] as bool? ?? false,
        );
      }).where((n) => n.ssid.isNotEmpty).toList();
    } on MissingPluginException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> connect(String ssid, {String password = ''}) async {
    try {
      await _channel.invokeMethod('connectWifi', {'ssid': ssid, 'password': password});
    } on MissingPluginException {
      // stub
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnectWifi');
    } on MissingPluginException {
      // stub
    }
  }

  Future<WifiStatus> getStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getWifiStatus');
      if (raw == null) return WifiStatus.disconnected;
      return WifiStatus(
        connected: raw['connected'] as bool? ?? false,
        ssid: raw['ssid'] as String? ?? '',
        txKbps: (raw['txKbps'] as num?)?.toDouble() ?? 0.0,
        rxKbps: (raw['rxKbps'] as num?)?.toDouble() ?? 0.0,
        bars: (raw['bars'] as num?)?.toInt() ?? 0,
        rssi: (raw['rssi'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return WifiStatus.disconnected;
    } catch (_) {
      return WifiStatus.disconnected;
    }
  }
}
