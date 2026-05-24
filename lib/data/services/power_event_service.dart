import 'package:flutter/services.dart';

enum PowerEvent { screenOff, screenOn, shutdown }

class PowerEventService {
  static const _channel = EventChannel('com.zero.dashflow_launcher/power_events');

  Stream<PowerEvent> get events => _channel
      .receiveBroadcastStream()
      .map((raw) => switch (raw as String) {
            'screen_off' => PowerEvent.screenOff,
            'screen_on'  => PowerEvent.screenOn,
            _            => PowerEvent.shutdown,
          });
}
