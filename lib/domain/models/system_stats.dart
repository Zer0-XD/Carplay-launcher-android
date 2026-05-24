/// Snapshot of live system telemetry emitted by the stats stream.
class SystemStats {
  const SystemStats({
    this.speedKmh = 0.0,
    this.cpuPercent = 0.0,
    this.memUsedMb = 0.0,
    this.hasNetwork = false,
    this.hasGps = false,
    this.signalBars = 0,
  });

  final double speedKmh;
  final double cpuPercent;
  final double memUsedMb;
  final bool hasNetwork;
  final bool hasGps;
  final int signalBars; // 0-4
}
