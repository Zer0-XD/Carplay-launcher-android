import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../data/services/location_service.dart';

const _kStyleUrl = 'https://tiles.openfreemap.org/styles/dark';

// ── Public API ────────────────────────────────────────────────────────────────

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

// ── State ─────────────────────────────────────────────────────────────────────

class _NavigationPageState extends State<NavigationPage> {
  MapLibreMapController? _mapController;
  Circle? _locationCircle;
  StreamSubscription<Position>? _locationSub;
  bool _disposed = false;

  LatLng _currentLatLng = const LatLng(0, 0);
  bool _initialPositionSet = false;

  // Search
  final _searchController = TextEditingController();
  List<_Place> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;

  // Route
  _Place? _destination;
  List<LatLng> _routeCoords = [];
  Line? _routeLine;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    final last = LocationService.instance.lastPosition;
    if (last != null) {
      _currentLatLng = LatLng(last.latitude, last.longitude);
      _initialPositionSet = true;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _locationSub?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _mapController = null;
    super.dispose();
  }

  // ── Map callbacks ───────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    _startTracking();
  }

  void _startTracking() {
    _locationSub = LocationService.instance.stream.listen((pos) async {
      if (_disposed) return;
      final latlng = LatLng(pos.latitude, pos.longitude);
      _currentLatLng = latlng;

      final ctrl = _mapController;
      if (ctrl == null) return;

      if (!_initialPositionSet) {
        _initialPositionSet = true;
        await ctrl.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: latlng, zoom: 16, tilt: 30),
          ),
        );
      } else {
        await ctrl.animateCamera(CameraUpdate.newLatLng(latlng));
      }

      if (_disposed || _mapController == null) return;

      if (_locationCircle == null) {
        _locationCircle = await ctrl.addCircle(
          CircleOptions(
            geometry: latlng,
            circleRadius: 10,
            circleColor: '#0A84FF',
            circleStrokeWidth: 2.5,
            circleStrokeColor: '#FFFFFF',
            circleOpacity: 1,
          ),
        );
      } else {
        await ctrl.updateCircle(
          _locationCircle!,
          CircleOptions(geometry: latlng),
        );
      }
    });
  }

  // ── Search (Nominatim) ──────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'CarPlayLauncher/1.0',
      });
      if (_disposed) return;
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        setState(() {
          _suggestions = list
              .map((e) => _Place.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (!_disposed) setState(() => _searching = false);
    }
  }

  // ── Routing (OSRM) ─────────────────────────────────────────────────────────

  Future<void> _routeTo(_Place place) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _destination = place;
      _routing = true;
      _searchController.text = place.displayName;
    });

    // Zoom to show both points
    final ctrl = _mapController;
    if (ctrl != null) {
      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLatLng.latitude < place.latlng.latitude
                  ? _currentLatLng.latitude
                  : place.latlng.latitude,
              _currentLatLng.longitude < place.latlng.longitude
                  ? _currentLatLng.longitude
                  : place.latlng.longitude,
            ),
            northeast: LatLng(
              _currentLatLng.latitude > place.latlng.latitude
                  ? _currentLatLng.latitude
                  : place.latlng.latitude,
              _currentLatLng.longitude > place.latlng.longitude
                  ? _currentLatLng.longitude
                  : place.latlng.longitude,
            ),
          ),
          left: 60,
          top: 100,
          right: 60,
          bottom: 160,
        ),
      );
    }

    try {
      final origin = _currentLatLng;
      final dest = place.latlng;
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/'
            '${origin.longitude},${origin.latitude};'
            '${dest.longitude},${dest.latitude}',
        {'overview': 'full', 'geometries': 'geojson'},
      );
      final res = await http.get(uri);
      if (_disposed) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final coords = (body['routes'][0]['geometry']['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();

        setState(() => _routeCoords = coords);

        final mapCtrl = _mapController;
        if (mapCtrl == null || _disposed) return;

        if (_routeLine != null) {
          await mapCtrl.removeLine(_routeLine!);
        }
        _routeLine = await mapCtrl.addLine(
          LineOptions(
            geometry: coords,
            lineColor: '#0A84FF',
            lineWidth: 4.5,
            lineOpacity: 0.9,
          ),
        );
      }
    } catch (_) {
    } finally {
      if (!_disposed) setState(() => _routing = false);
    }
  }

  void _clearRoute() {
    _searchController.clear();
    setState(() {
      _destination = null;
      _suggestions = [];
      _routeCoords = [];
    });
    if (_routeLine != null) {
      _mapController?.removeLine(_routeLine!);
      _routeLine = null;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────────
          Positioned.fill(
            child: MapLibreMap(
              styleString: _kStyleUrl,
              initialCameraPosition: CameraPosition(
                target: _currentLatLng,
                zoom: _initialPositionSet ? 15 : 2,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              myLocationEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              doubleClickZoomEnabled: true,
              dragEnabled: true,
            ),
          ),

          // ── Top bar: back + search ────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: _SearchBar(
              controller: _searchController,
              searching: _searching,
              hasDestination: _destination != null,
              onChanged: _onSearchChanged,
              onClear: _clearRoute,
            ),
          ),

          // ── Suggestions dropdown ──────────────────────────────────────────
          if (_suggestions.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 66,
              left: 12,
              right: 12,
              child: _SuggestionList(
                places: _suggestions,
                onTap: _routeTo,
              ),
            ),

          // ── Close button ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: _CircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Recenter button ───────────────────────────────────────────────
          Positioned(
            bottom: 28,
            right: 16,
            child: _CircleButton(
              icon: Icons.my_location_rounded,
              onTap: () {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _currentLatLng,
                      zoom: 16,
                      tilt: 30,
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Route loading indicator ───────────────────────────────────────
          if (_routing)
            const Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Center(
                child: _RoutingChip(),
              ),
            ),

          // ── Route info bar ────────────────────────────────────────────────
          if (_destination != null && !_routing)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _RouteInfoBar(
                destination: _destination!,
                routeCoords: _routeCoords,
                onClear: _clearRoute,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searching,
    required this.hasDestination,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool searching;
  final bool hasDestination;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(left: 48),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search destination…',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (searching)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          else if (hasDestination || controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Suggestions list ──────────────────────────────────────────────────────────

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.places, required this.onTap});

  final List<_Place> places;
  final ValueChanged<_Place> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: places.asMap().entries.map((entry) {
          final i = entry.key;
          final place = entry.value;
          return GestureDetector(
            onTap: () => onTap(place),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: i < places.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: Colors.white.withAlpha(15),
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_rounded, size: 16, color: Colors.white38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      place.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Route info bar ────────────────────────────────────────────────────────────

class _RouteInfoBar extends StatelessWidget {
  const _RouteInfoBar({
    required this.destination,
    required this.routeCoords,
    required this.onClear,
  });

  final _Place destination;
  final List<LatLng> routeCoords;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(220),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(20), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, color: Color(0xFF0A84FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              destination.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(200),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'End',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Routing loading chip ──────────────────────────────────────────────────────

class _RoutingChip extends StatelessWidget {
  const _RoutingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0A84FF),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Calculating route…',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Circular icon button ──────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(210),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withAlpha(30), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

// ── Place model ───────────────────────────────────────────────────────────────

class _Place {
  const _Place({required this.displayName, required this.latlng});

  final String displayName;
  final LatLng latlng;

  factory _Place.fromJson(Map<String, dynamic> json) {
    return _Place(
      displayName: json['display_name'] as String,
      latlng: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
    );
  }
}
