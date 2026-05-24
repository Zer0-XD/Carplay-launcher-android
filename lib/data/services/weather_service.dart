import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart';

/// WMO weather interpretation codes → icon + label
const _wmoDescriptions = {
  0: ('☀️', 'Clear'),
  1: ('🌤', 'Mostly Clear'),
  2: ('⛅', 'Partly Cloudy'),
  3: ('☁️', 'Overcast'),
  45: ('🌫', 'Fog'),
  48: ('🌫', 'Icy Fog'),
  51: ('🌦', 'Drizzle'),
  53: ('🌦', 'Drizzle'),
  55: ('🌧', 'Heavy Drizzle'),
  61: ('🌧', 'Rain'),
  63: ('🌧', 'Rain'),
  65: ('🌧', 'Heavy Rain'),
  71: ('🌨', 'Snow'),
  73: ('🌨', 'Snow'),
  75: ('❄️', 'Heavy Snow'),
  77: ('🌨', 'Snow Grains'),
  80: ('🌦', 'Showers'),
  81: ('🌧', 'Showers'),
  82: ('⛈', 'Heavy Showers'),
  85: ('🌨', 'Snow Showers'),
  86: ('🌨', 'Snow Showers'),
  95: ('⛈', 'Thunderstorm'),
  96: ('⛈', 'Thunderstorm+Hail'),
  99: ('⛈', 'Thunderstorm+Hail'),
};

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.tempMaxC,
    required this.tempMinC,
    required this.weatherCode,
  });

  final DateTime date;
  final double tempMaxC;
  final double tempMinC;
  final int weatherCode;

  String get emoji => _wmoDescriptions[weatherCode]?.$1 ?? '🌡';
  String get label => _wmoDescriptions[weatherCode]?.$2 ?? 'Unknown';
}

class WeatherData {
  const WeatherData({
    required this.currentTempC,
    required this.currentWeatherCode,
    required this.forecast,
    this.cityName,
  });

  final double currentTempC;
  final int currentWeatherCode;
  final List<WeatherDay> forecast; // today + 3 days
  final String? cityName;

  String get emoji => _wmoDescriptions[currentWeatherCode]?.$1 ?? '🌡';
  String get label => _wmoDescriptions[currentWeatherCode]?.$2 ?? '';
}

class WeatherService {
  WeatherService._();
  static final instance = WeatherService._();

  Stream<WeatherData> get stream => _controller.stream;
  WeatherData? get last => _last;

  final _controller = StreamController<WeatherData>.broadcast();
  WeatherData? _last;
  Timer? _timer;
  bool _running = false;
  String? _cachedCity;

  void start() {
    if (_running) return;
    _running = true;
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetch() async {
    try {
      Position? pos = LocationService.instance.lastPosition;
      if (pos == null) {
        try {
          pos = await LocationService.instance.stream.first
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          return;
        }
      }

      final lat = pos.latitude;
      final lon = pos.longitude;

      // Reverse-geocode once per session (city rarely changes while driving)
      _cachedCity ??= await _reverseGeocode(lat, lon);

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,weather_code'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&forecast_days=4'
        '&timezone=auto',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>;

      final dates = (daily['time'] as List).cast<String>();
      final maxTemps = (daily['temperature_2m_max'] as List).cast<num>();
      final minTemps = (daily['temperature_2m_min'] as List).cast<num>();
      final codes = (daily['weather_code'] as List).cast<num>();

      final forecast = List.generate(
        dates.length.clamp(0, 4),
        (i) => WeatherDay(
          date: DateTime.parse(dates[i]),
          tempMaxC: maxTemps[i].toDouble(),
          tempMinC: minTemps[i].toDouble(),
          weatherCode: codes[i].toInt(),
        ),
      );

      final data = WeatherData(
        currentTempC: (current['temperature_2m'] as num).toDouble(),
        currentWeatherCode: (current['weather_code'] as num).toInt(),
        forecast: forecast,
        cityName: _cachedCity,
      );

      _last = data;
      if (!_controller.isClosed) _controller.add(data);
    } catch (_) {
      // Silently ignore network errors — keep showing last data
    }
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lon&format=json&zoom=10',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'CarplayLauncher/1.0'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      // Prefer city > town > village > county, in that order
      return (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['county']) as String?;
    } catch (_) {
      return null;
    }
  }
}
