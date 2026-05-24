import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/media_service.dart';
import '../../data/services/power_event_service.dart';

class MediaProvider extends ChangeNotifier {
  final MediaService _service;
  final PowerEventService _powerService;
  Timer? _pollTimer;
  Timer? _permTimer;
  StreamSubscription<PowerEvent>? _powerSub;

  MediaInfo _info = MediaInfo.empty;
  MediaInfo get info => _info;

  bool _permissionGranted = true;
  bool get permissionGranted => _permissionGranted;

  // Suppress position polls for a short window after a seek so the optimistic
  // position doesn't get immediately overwritten by a stale poll response.
  bool _seeking = false;

  // Whether polling is suspended due to screen-off / shutdown
  bool _screenOff = false;

  MediaProvider(this._service, this._powerService) {
    _checkPermission();
    _poll();
    // Poll media every 1 s for low latency
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
    // Re-check permission every 10 s (not every tick — it's slow)
    _permTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkPermission());
    _listenPowerEvents();
  }

  void _listenPowerEvents() {
    _powerSub = _powerService.events.listen((event) {
      switch (event) {
        case PowerEvent.screenOff:
          _screenOff = true;
          // Pause playback when screen turns off (car display sleeps)
          _service.pause();
        case PowerEvent.shutdown:
          _screenOff = true;
          // Pause is already sent natively on shutdown; mirror state here
          _info = MediaInfo(
            isPlaying: false,
            title: _info.title,
            artist: _info.artist,
            album: _info.album,
            albumArt: _info.albumArt,
            duration: _info.duration,
            position: _info.position,
          );
          notifyListeners();
        case PowerEvent.screenOn:
          _screenOff = false;
          _poll(); // refresh immediately when screen comes back
      }
    });
  }

  Future<void> _checkPermission() async {
    final granted = await _service.isNotificationListenerGranted();
    if (granted != _permissionGranted) {
      _permissionGranted = granted;
      notifyListeners();
    }
  }

  Future<void> requestPermission() => _service.openNotificationListenerSettings();

  Future<void> _poll() async {
    if (!_permissionGranted || _seeking || _screenOff) return;
    final fresh = await _service.getMediaInfo();
    if (_changed(fresh)) {
      _info = fresh;
      notifyListeners();
    }
  }

  bool _changed(MediaInfo n) {
    final o = _info;
    final positionDrift = (n.position.inMilliseconds - o.position.inMilliseconds).abs();
    return o.isPlaying != n.isPlaying ||
        o.title != n.title ||
        o.artist != n.artist ||
        o.albumArt != n.albumArt ||
        positionDrift > 1500;
  }

  Future<void> playPause() async {
    // Optimistic update so the button flips instantly
    _info = MediaInfo(
      isPlaying: !_info.isPlaying,
      title: _info.title,
      artist: _info.artist,
      album: _info.album,
      albumArt: _info.albumArt,
      duration: _info.duration,
      position: _info.position,
    );
    notifyListeners();
    if (_info.isPlaying) {
      await _service.play();
    } else {
      await _service.pause();
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _poll();
  }

  Future<void> next() async {
    await _service.next();
    await Future.delayed(const Duration(milliseconds: 300));
    await _poll();
  }

  Future<void> previous() async {
    await _service.previous();
    await Future.delayed(const Duration(milliseconds: 300));
    await _poll();
  }

  Future<void> seekTo(Duration position) async {
    // Optimistic update so the scrubber moves instantly.
    _seeking = true;
    _info = MediaInfo(
      isPlaying: _info.isPlaying,
      title: _info.title,
      artist: _info.artist,
      album: _info.album,
      albumArt: _info.albumArt,
      duration: _info.duration,
      position: position,
    );
    notifyListeners();
    await _service.seekTo(position);
    // Give the media app 600 ms to update its PlaybackState before resuming polls.
    await Future.delayed(const Duration(milliseconds: 600));
    _seeking = false;
    await _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _permTimer?.cancel();
    _powerSub?.cancel();
    super.dispose();
  }
}
