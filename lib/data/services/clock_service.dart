import 'dart:async';

/// Emits the current [DateTime] every second.
///
/// Uses a single shared broadcast stream so multiple widgets can subscribe
/// without creating duplicate timers — important on 2 GB RAM devices.
class ClockService {
  ClockService._();
  static final ClockService instance = ClockService._();

  late final Stream<DateTime> stream = _build();

  Stream<DateTime> _build() {
    late StreamController<DateTime> controller;
    Timer? timer;

    controller = StreamController<DateTime>.broadcast(
      onListen: () {
        controller.add(DateTime.now());
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          controller.add(DateTime.now());
        });
      },
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );

    return controller.stream;
  }
}
