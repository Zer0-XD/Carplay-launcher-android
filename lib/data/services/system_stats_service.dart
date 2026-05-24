import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../domain/models/system_stats.dart';

/// Streams [SystemStats] snapshots throttled to once every 2 seconds.
///
/// On a 2 GB head unit a 2-second poll interval balances freshness against
/// GC pressure from frequent Dart object allocation.  The native side is
/// queried via a MethodChannel; a pure-Dart stub is used when the channel
/// is unavailable (desktop/test environments).
class SystemStatsService {
  SystemStatsService._();
  static final SystemStatsService instance = SystemStatsService._();

  static const _channel =
      MethodChannel('com.zero.dashflow_launcher/system');

  late final Stream<SystemStats> stream = _build();

  Stream<SystemStats> _build() {
    late StreamController<SystemStats> controller;
    Timer? timer;

    controller = StreamController<SystemStats>.broadcast(
      onListen: () async {
        controller.add(await _poll());
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          if (!controller.hasListener) return;
          controller.add(await _poll());
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }

  Future<SystemStats> _poll() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getSystemStats');
      if (raw == null) return _stub();
      return SystemStats(
        speedKmh: (raw['speedKmh'] as num?)?.toDouble() ?? 0.0,
        cpuPercent: (raw['cpuPercent'] as num?)?.toDouble() ?? 0.0,
        memUsedMb: (raw['memUsedMb'] as num?)?.toDouble() ?? 0.0,
        hasNetwork: raw['hasNetwork'] as bool? ?? false,
        hasGps: raw['hasGps'] as bool? ?? false,
        signalBars: (raw['signalBars'] as int?) ?? 0,
      );
    } on MissingPluginException {
      return _stub();
    } catch (_) {
      return _stub();
    }
  }

  // Generates plausible fake data for non-Android environments.
  static final _rng = math.Random();
  static SystemStats _stub() => SystemStats(
        speedKmh: (_rng.nextDouble() * 120).roundToDouble(),
        cpuPercent: 20 + _rng.nextDouble() * 40,
        memUsedMb: 800 + _rng.nextDouble() * 400,
        hasNetwork: true,
        hasGps: true,
        signalBars: 3,
      );
}
