import 'package:flutter/material.dart';
import '../../../data/services/weather_service.dart';
import 'base_card.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({
    super.key,
    this.isEditing = false,
    this.onLongPress,
    this.isLarge = false,
  });

  final bool isEditing;
  final VoidCallback? onLongPress;
  final bool isLarge;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  @override
  void initState() {
    super.initState();
    WeatherService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      isEditing: widget.isEditing,
      onLongPress: widget.onLongPress,
      padding: EdgeInsets.zero,
      accentColor: const Color(0xFF38BDF8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final s = (constraints.smallest.shortestSide / 200.0).clamp(0.5, 2.0);
          final wide = constraints.maxWidth > constraints.maxHeight * 1.3;
          return StreamBuilder<WeatherData>(
            stream: WeatherService.instance.stream,
            initialData: WeatherService.instance.last,
            builder: (context, snap) {
              final data = snap.data;
              if (data == null) return _Loading(s: s);
              return wide
                  ? _WideWeather(data: data, s: s)
                  : _CompactWeather(data: data, s: s);
            },
          );
        },
      ),
    );
  }
}

// ── Compact: icon + temp + label ──────────────────────────────────────────────

class _CompactWeather extends StatelessWidget {
  const _CompactWeather({required this.data, required this.s});
  final WeatherData data;
  final double s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(14 * s),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.emoji, style: TextStyle(fontSize: 32 * s)),
          SizedBox(height: 6 * s),
          Text(
            '${data.currentTempC.round()}°',
            style: TextStyle(
              fontSize: 32 * s, fontWeight: FontWeight.w200,
              color: scheme.onSurface, height: 1,
            ),
          ),
          SizedBox(height: 4 * s),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 10 * s, color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500, letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.cityName != null) ...[
            SizedBox(height: 3 * s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded,
                    size: 9 * s, color: const Color(0xFF38BDF8).withAlpha(160)),
                SizedBox(width: 2 * s),
                Flexible(
                  child: Text(
                    data.cityName!,
                    style: TextStyle(
                      fontSize: 9 * s, color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Wide: current conditions + forecast strip ─────────────────────────────────

class _WideWeather extends StatelessWidget {
  const _WideWeather({required this.data, required this.s});
  final WeatherData data;
  final double s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Use smaller padding and emoji tile when height is tight
    final p = (12 * s).clamp(8.0, 16.0);
    final tileSize = (48 * s).clamp(36.0, 58.0);
    final emojiSize = (tileSize * 0.6).clamp(20.0, 32.0);
    return Padding(
      padding: EdgeInsets.all(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant, width: 1),
                ),
                child: Center(child: Text(data.emoji, style: TextStyle(fontSize: emojiSize))),
              ),
              SizedBox(width: 14 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.currentTempC.round()}°C',
                      style: TextStyle(
                        fontSize: (28 * s).clamp(20.0, 36.0), fontWeight: FontWeight.w200,
                        color: scheme.onSurface, height: 1,
                      ),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      data.label,
                      style: TextStyle(
                        fontSize: (10 * s).clamp(8.0, 12.0), color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (data.cityName != null) ...[
                      SizedBox(height: 4 * s),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 10 * s, color: const Color(0xFF38BDF8).withAlpha(180)),
                          SizedBox(width: 3 * s),
                          Flexible(
                            child: Text(
                              data.cityName!,
                              style: TextStyle(
                                fontSize: 10 * s, color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (data.forecast.isNotEmpty) ...[
                    Text(
                      '${data.forecast.first.tempMaxC.round()}°',
                      style: TextStyle(
                        fontSize: 16 * s, fontWeight: FontWeight.w600, color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${data.forecast.first.tempMinC.round()}°',
                      style: TextStyle(
                        fontSize: 13 * s, color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const Spacer(),

          if (data.forecast.isNotEmpty) ...[
            Container(
              height: 1,
              margin: EdgeInsets.only(bottom: 8 * s),
              color: scheme.outlineVariant.withAlpha(80),
            ),
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: data.forecast.map((day) {
                  const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final today = day.date.day == DateTime.now().day;
                  final label = today ? 'Today' : names[day.date.weekday];
                  return Expanded(child: _ForecastCell(
                    label: label, emoji: day.emoji,
                    high: day.tempMaxC.round(), low: day.tempMinC.round(),
                    isToday: today, s: s,
                  ));
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForecastCell extends StatelessWidget {
  const _ForecastCell({
    required this.label, required this.emoji,
    required this.high, required this.low,
    required this.isToday, required this.s,
  });
  final String label, emoji;
  final int high, low;
  final bool isToday;
  final double s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1 * s),
      padding: EdgeInsets.symmetric(vertical: 4 * s),
      decoration: isToday
          ? BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF38BDF8).withAlpha(80), width: 0.8),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: (9 * s).clamp(7.0, 10.0),
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              color: isToday
                  ? const Color(0xFF38BDF8)
                  : scheme.onSurfaceVariant,
            )),
          SizedBox(height: 2 * s),
          Text(emoji, style: TextStyle(fontSize: (16 * s).clamp(12.0, 20.0))),
          SizedBox(height: 2 * s),
          Text('$high°',
            style: TextStyle(
              fontSize: (11 * s).clamp(9.0, 13.0), fontWeight: FontWeight.w600, color: scheme.onSurface,
            )),
          Text('$low°',
            style: TextStyle(
              fontSize: (9 * s).clamp(7.0, 11.0), color: scheme.onSurfaceVariant,
            )),
        ],
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading({required this.s});
  final double s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🌡', style: TextStyle(fontSize: 28 * s)),
          SizedBox(height: 8 * s),
          SizedBox(
            width: 16 * s,
            height: 16 * s,
            child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(60)),
          ),
        ],
      ),
    );
  }
}
