import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

/// Emits GPS speed in km/h once per second derived from [LocationService].
/// Negative speed (no fix yet) is clamped to 0.
class SpeedService {
  SpeedService._();
  static final instance = SpeedService._();

  StreamController<double>? _controller;
  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  double _lastKmh = 0;

  Stream<double> get stream {
    _controller ??= StreamController<double>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
    return _controller!.stream;
  }

  void _start() {
    // Update internal value on every GPS fix
    _sub = LocationService.instance.stream.listen((pos) {
      final kmh = (pos.speed < 0 ? 0 : pos.speed) * 3.6;
      _lastKmh = kmh;
    });

    // Emit on a 1-second heartbeat regardless of GPS update rate
    _controller?.add(_lastKmh);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _controller?.add(_lastKmh);
    });
  }

  void _stop() {
    _sub?.cancel();
    _ticker?.cancel();
    _sub = null;
    _ticker = null;
    _controller = null;
  }
}
