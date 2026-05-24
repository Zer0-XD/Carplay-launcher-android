import 'package:flutter/services.dart';

class MediaInfo {
  final bool isPlaying;
  final String title;
  final String artist;
  final String album;
  final Uint8List? albumArt;
  final Duration duration;
  final Duration position;

  const MediaInfo({
    required this.isPlaying,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    required this.duration,
    required this.position,
  });

  bool get hasContent => title.isNotEmpty || artist.isNotEmpty;

  static const empty = MediaInfo(
    isPlaying: false,
    title: '',
    artist: '',
    album: '',
    albumArt: null,
    duration: Duration.zero,
    position: Duration.zero,
  );

  factory MediaInfo.fromMap(Map<dynamic, dynamic> map) {
    final artRaw = map['albumArt'];
    Uint8List? art;
    if (artRaw is Uint8List) {
      art = artRaw;
    } else if (artRaw is List) {
      art = Uint8List.fromList(artRaw.cast<int>());
    }
    return MediaInfo(
      isPlaying: (map['isPlaying'] as bool?) ?? false,
      title: (map['title'] as String?) ?? '',
      artist: (map['artist'] as String?) ?? '',
      album: (map['album'] as String?) ?? '',
      albumArt: art,
      duration: Duration(milliseconds: (map['duration'] as int?) ?? 0),
      position: Duration(milliseconds: (map['position'] as int?) ?? 0),
    );
  }
}

class MediaService {
  static const _channel = MethodChannel('com.zero.dashflow_launcher/media');

  Future<MediaInfo> getMediaInfo() async {
    try {
      final raw = await _channel.invokeMethod<Map>('getMediaInfo');
      if (raw == null) return MediaInfo.empty;
      return MediaInfo.fromMap(raw);
    } catch (_) {
      return MediaInfo.empty;
    }
  }

  Future<void> play() => _command('play');
  Future<void> pause() => _command('pause');
  Future<void> next() => _command('next');
  Future<void> previous() => _command('previous');
  Future<void> seekTo(Duration position) => _command('seekTo', positionMs: position.inMilliseconds);

  Future<bool> isNotificationListenerGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationListenerGranted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (_) {}
  }

  Future<void> _command(String cmd, {int? positionMs}) async {
    try {
      final args = <String, dynamic>{'command': cmd};
      if (positionMs != null) args['positionMs'] = positionMs;
      await _channel.invokeMethod('mediaCommand', args);
    } catch (_) {}
  }
}
