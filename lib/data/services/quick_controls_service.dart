import 'dart:async';
import 'package:flutter/services.dart';

/// Android audio stream types (mirrors AudioManager constants).
class AudioStream {
  static const int music = 3;
  static const int ring = 2;
  static const int notification = 5;
  static const int alarm = 4;
}

class VolumeInfo {
  const VolumeInfo({required this.current, required this.max});
  final int current;
  final int max;
  double get fraction => max > 0 ? current / max : 0;
}

class QuickControlsService {
  QuickControlsService._();
  static final instance = QuickControlsService._();

  static const _ch = MethodChannel('com.zero.dashflow_launcher/quick_controls');

  // ── Volume ──────────────────────────────────────────────────────────────────

  Future<VolumeInfo> getVolume({int stream = AudioStream.music}) async {
    try {
      final raw = await _ch.invokeMethod<Map<dynamic, dynamic>>(
          'getVolume', {'stream': stream});
      if (raw == null) return const VolumeInfo(current: 0, max: 15);
      return VolumeInfo(
        current: (raw['current'] as num).toInt(),
        max: (raw['max'] as num).toInt(),
      );
    } on MissingPluginException {
      return const VolumeInfo(current: 8, max: 15);
    }
  }

  Future<void> setVolume(int value, {int stream = AudioStream.music}) async {
    try {
      await _ch.invokeMethod('setVolume', {'stream': stream, 'value': value});
    } on MissingPluginException {
      // Running on desktop/simulator — ignore
    }
  }

  // ── Brightness ──────────────────────────────────────────────────────────────

  /// Returns brightness 0–255.
  Future<int> getBrightness() async {
    try {
      return await _ch.invokeMethod<int>('getBrightness') ?? 128;
    } on MissingPluginException {
      return 128;
    }
  }

  /// [value] is 0–255.
  Future<void> setBrightness(int value) async {
    try {
      await _ch.invokeMethod('setBrightness', {'value': value});
    } on MissingPluginException {}
  }

  // ── WiFi ────────────────────────────────────────────────────────────────────

  Future<bool> getWifiEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('getWifiEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setWifiEnabled(bool enabled) async {
    try {
      await _ch.invokeMethod('setWifiEnabled', {'enabled': enabled});
    } on MissingPluginException {}
  }

  // ── Bluetooth ───────────────────────────────────────────────────────────────

  Future<bool> getBluetoothEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('getBluetoothEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setBluetoothEnabled(bool enabled) async {
    try {
      await _ch.invokeMethod('setBluetoothEnabled', {'enabled': enabled});
    } on MissingPluginException {}
  }
}
