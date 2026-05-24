import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Singleton GPS stream. Requests permission once, then emits [Position]
/// updates at the highest available accuracy. Consumers just listen to
/// [stream] — no lifecycle management needed.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  StreamController<Position>? _controller;
  StreamSubscription<Position>? _sub;
  Position? _last;

  Position? get lastPosition => _last;

  Stream<Position> get stream {
    _controller ??= StreamController<Position>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
    return _controller!.stream;
  }

  Future<void> _start() async {
    // Check / request permission
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) return;

    // Get an immediate fix before the stream starts
    try {
      _last = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _controller?.add(_last!);
    } catch (_) {}

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // metres — don't spam on stationary
      ),
    ).listen((pos) {
      _last = pos;
      _controller?.add(pos);
    });
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    // Null the controller so the next call to stream creates a fresh one
    // with a new onListen callback — reusing a closed broadcast controller
    // leaves the stream permanently dead after all listeners detach.
    _controller = null;
  }
}
