import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'map/place.dart';
import 'map/places_data.dart';
import 'map/crowd_zone.dart';
import 'map/crowd_data.dart';
import 'map/crowd_api_service.dart';
import 'map/directions_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  MapType currentMapType = MapType.normal;

  static const LatLng haram = LatLng(21.4225, 39.8262);
  static const Color backgroundColor = Color(0xFF0B0F1A);
  static const Color accentColor = Color(0xFFF2B233);

  // ---------- LIVE CROWD STATE ----------
  List<CrowdZone> crowdZones = CrowdData.sampleZones;
  Timer? _crowdRefreshTimer;
  DateTime? _lastCrowdUpdate;
  bool _crowdLive = false;

  // ---------- NAVIGATION STATE ----------
  Place? selectedPlace;
  DirectionsResult? activeRoute;
  bool isLoadingRoute = false;
  bool routePassesCrowdedZone = false;

  // ---------- PROXIMITY ALERT STATE (FR8.4) ----------
  Timer? _proximityTimer;
  final Set<String> _alertedZoneIds = {};
  static const double _alertRadius = 150;
  LocationPermission? _cachedPermission; // cache permission — don't check every tick

  // ---------- PLACE CATEGORY FILTER ----------
  String _selectedCategory = "all";

  // ---------- LIFECYCLE ----------
  @override
  void initState() {
    super.initState();
    // Delay first load so Google Maps finishes rendering first
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _refreshCrowdData();
    });
    _crowdRefreshTimer = Timer.periodic(
      const Duration(seconds: 60), // reduced from 30s to ease emulator load
      (_) => _refreshCrowdData(),
    );
    // Start proximity checks after 15s delay — let the map settle first
    Future.delayed(const Duration(seconds: 15), () {
      if (!mounted) return;
      _proximityTimer = Timer.periodic(
        const Duration(seconds: 30), // reduced from 10s to avoid GPS hammering
        (_) => _checkProximityAlert(),
      );
    });
  }

  @override
  void dispose() {
    _crowdRefreshTimer?.cancel();
    _proximityTimer?.cancel();
    super.dispose();
  }

  // ---------- CROWD API ----------
  Future<void> _refreshCrowdData() async {
    final fetched = await CrowdApiService.fetchCrowdZones();
    if (!mounted) return;

    final wasLive = !identical(fetched, CrowdData.sampleZones);

    setState(() {
      crowdZones = fetched;
      _lastCrowdUpdate = DateTime.now();
      _crowdLive = wasLive;
    });

    if (activeRoute != null) {
      final passes = _checkRoutePassesCrowdedZone(activeRoute!.points);
      if (passes != routePassesCrowdedZone) {
        setState(() => routePassesCrowdedZone = passes);
      }
    }
  }

  // ---------- PROXIMITY ALERT (FR8.4) ----------
  Future<void> _checkProximityAlert() async {
    final position = await _getCurrentPosition();
    if (position == null || !mounted) return;

    for (final zone in crowdZones) {
      // Only alert for RED (crowded) zones
      if (zone.density < 0.7) {
        // If a zone is no longer red, reset its alert so it can fire again
        _alertedZoneIds.remove(zone.id);
        continue;
      }

      // Already warned about this zone? Skip.
      if (_alertedZoneIds.contains(zone.id)) continue;

      // Calculate distance from user to the zone center
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      // If user is within alert radius, show the warning
      if (distance <= _alertRadius) {
        _alertedZoneIds.add(zone.id); // mark as alerted
        _showProximityAlert(zone, distance);
        break; // only one alert at a time
      }
    }
  }

  void _showProximityAlert(CrowdZone zone, double distance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Crowded Area Ahead",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _alertInfoRow(Icons.place, zone.name),
            const SizedBox(height: 8),
            _alertInfoRow(
              Icons.people,
              "Status: ${zone.levelLabel} (${(zone.density * 100).round()}%)",
            ),
            const SizedBox(height: 8),
            _alertInfoRow(Icons.straighten, "${distance.round()} meters away"),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Consider waiting or taking an alternative route for your safety.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(zone.center, 17),
              );
            },
            child: const Text("Show on Map"),
          ),
        ],
      ),
    );
  }

  Widget _alertInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  // ---------- LOCATION ----------
  Future<Position?> _getCurrentPosition() async {
    // Use cached permission to avoid repeated OS calls every timer tick
    _cachedPermission ??= await Geolocator.checkPermission();
    if (_cachedPermission == LocationPermission.denied ||
        _cachedPermission == LocationPermission.deniedForever) {
      _cachedPermission = await Geolocator.requestPermission();
      if (_cachedPermission == LocationPermission.denied ||
          _cachedPermission == LocationPermission.deniedForever) {
        return null;
      }
    }
    try {
      // getLastKnownPosition is instant — no GPS hardware wait
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      // Only fall back to full GPS if no cached position, with a hard timeout
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _goToMyLocation() async {
    final position = await _getCurrentPosition();
    if (position == null) return;
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        17,
      ),
    );
  }

  // ---------- NAVIGATE ----------
  Future<void> _navigateTo(Place place) async {
    setState(() {
      selectedPlace = place;
      isLoadingRoute = true;
      activeRoute = null;
      routePassesCrowdedZone = false;
    });

    final position = await _getCurrentPosition();
    if (position == null) {
      _showSnack("⚠️ Could not get your location. Please enable GPS.");
      setState(() => isLoadingRoute = false);
      return;
    }

    final origin = LatLng(position.latitude, position.longitude);
    final result = await DirectionsService.getRoute(
      origin: origin,
      destination: place.location,
    );

    if (result == null) {
      _showSnack("⚠️ Could not find a route. Try again.");
      setState(() => isLoadingRoute = false);
      return;
    }

    final passesCrowded = _checkRoutePassesCrowdedZone(result.points);

    setState(() {
      activeRoute = result;
      isLoadingRoute = false;
      routePassesCrowdedZone = passesCrowded;
    });

    _fitCameraToRoute(result.points);
  }

  void _cancelNavigation() {
    setState(() {
      selectedPlace = null;
      activeRoute = null;
      routePassesCrowdedZone = false;
    });
  }

  bool _checkRoutePassesCrowdedZone(List<LatLng> routePoints) {
    for (final zone in crowdZones) {
      if (zone.density < 0.7) continue;
      for (final point in routePoints) {
        final distance = Geolocator.distanceBetween(
          point.latitude,
          point.longitude,
          zone.center.latitude,
          zone.center.longitude,
        );
        if (distance <= zone.radius) return true;
      }
    }
    return false;
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty || mapController == null) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  // ---------- BEST TIME TO VISIT (FR8.5) ----------
  // Shows a bottom sheet with crowd info + suggested best time for a zone
  void _showZoneInfo(CrowdZone zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Zone name + status
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: zone.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    zone.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: zone.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${zone.levelLabel} (${(zone.density * 100).round()}%)",
                    style: TextStyle(
                      color: zone.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Best time to visit
            if (zone.bestTime.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Best Time to Visit",
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      zone.bestTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (zone.bestTimeNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        zone.bestTimeNote,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(zone.center, 17),
                      );
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("Show on Map"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Got it"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------- MARKERS / CIRCLES / POLYLINES ----------
  Set<Marker> _buildMarkers() {
    return PlacesData.all.map((place) {
      final isSelected = selectedPlace?.id == place.id;
      return Marker(
        markerId: MarkerId(place.id),
        position: place.location,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueAzure
              : _markerHueFor(place.category),
        ),
        infoWindow: InfoWindow(title: place.name, snippet: place.description),
      );
    }).toSet();
  }

  double _markerHueFor(String category) {
    switch (category) {
      case "holy":
        return BitmapDescriptor.hueRed;
      case "gate":
        return BitmapDescriptor.hueOrange;
      case "service":
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  Set<Circle> _buildCrowdCircles() {
    return crowdZones.map((zone) {
      return Circle(
        circleId: CircleId(zone.id),
        center: zone.center,
        radius: zone.radius,
        fillColor: zone.color.withOpacity(0.30),
        strokeColor: zone.color,
        strokeWidth: 2,
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    if (activeRoute == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId("route"),
        points: activeRoute!.points,
        color: routePassesCrowdedZone
            ? const Color(0xFFF2B233)
            : const Color(0xFF1E88E5),
        width: 6,
      ),
    };
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryTabs(),
            _buildPlaceList(),
            Expanded(child: _buildMap()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Text(
            "Map",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          _buildLiveIndicator(),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _crowdLive
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _crowdLive ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _crowdLive ? Colors.greenAccent : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _crowdLive ? "LIVE" : "OFFLINE",
            style: TextStyle(
              color: _crowdLive ? Colors.greenAccent : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            GoogleMap(
              mapType: currentMapType,
              initialCameraPosition: const CameraPosition(
                target: haram,
                zoom: 16,
              ),
              onMapCreated: (controller) => mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _buildMarkers(),
              circles: _buildCrowdCircles(),
              polylines: _buildPolylines(),
              // When user taps on the map, check if they tapped a crowd zone
              onTap: (LatLng tappedPoint) {
                for (final zone in crowdZones) {
                  final distance = Geolocator.distanceBetween(
                    tappedPoint.latitude,
                    tappedPoint.longitude,
                    zone.center.latitude,
                    zone.center.longitude,
                  );
                  if (distance <= zone.radius) {
                    _showZoneInfo(zone);
                    return;
                  }
                }
              },
            ),

            // Map type (top left)
            Positioned(
              left: 12,
              top: 12,
              child: _circleButton(
                heroTag: "map_type",
                icon: Icons.layers,
                onPressed: () {
                  setState(() {
                    currentMapType = currentMapType == MapType.normal
                        ? MapType.satellite
                        : MapType.normal;
                  });
                },
              ),
            ),

            // Zoom + refresh (top right)
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  _circleButton(
                    heroTag: "zoom_in",
                    icon: Icons.add,
                    onPressed: () =>
                        mapController?.animateCamera(CameraUpdate.zoomIn()),
                  ),
                  const SizedBox(height: 8),
                  _circleButton(
                    heroTag: "zoom_out",
                    icon: Icons.remove,
                    onPressed: () =>
                        mapController?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                  const SizedBox(height: 8),
                  _circleButton(
                    heroTag: "refresh_crowd",
                    icon: Icons.refresh,
                    onPressed: _refreshCrowdData,
                  ),
                ],
              ),
            ),

            // Crowd legend (bottom left, only when no active route)
            if (activeRoute == null && !isLoadingRoute)
              Positioned(bottom: 12, left: 12, child: _buildCrowdLegend()),

            // My location (bottom right)
            Positioned(
              bottom: 12,
              right: 12,
              child: _circleButton(
                heroTag: "my_location",
                icon: Icons.my_location,
                large: true,
                onPressed: _goToMyLocation,
              ),
            ),

            // Loading overlay
            if (isLoadingRoute)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accentColor),
                      SizedBox(height: 12),
                      Text(
                        "Finding the best route...",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            // Route info card (top center)
            if (activeRoute != null && selectedPlace != null)
              Positioned(
                top: 12,
                left: 70,
                right: 70,
                child: _buildRouteInfoCard(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, color: Colors.red, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  selectedPlace!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _cancelNavigation,
                child: const Icon(Icons.close, size: 20, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.directions_walk,
                size: 16,
                color: Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                "${activeRoute!.distanceText}  •  ${activeRoute!.durationText}",
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          if (routePassesCrowdedZone) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "Path goes through a crowded area",
                      style: TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrowdLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Crowd Level",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          const _LegendRow(color: Colors.green, label: "Safe"),
          const _LegendRow(color: Colors.orange, label: "Medium"),
          const _LegendRow(color: Colors.red, label: "Crowded"),
          if (_lastCrowdUpdate != null) ...[
            const SizedBox(height: 4),
            Text(
              "Updated ${_timeAgoText(_lastCrowdUpdate!)}",
              style: const TextStyle(fontSize: 9, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgoText(DateTime time) {
    final seconds = DateTime.now().difference(time).inSeconds;
    if (seconds < 5) return "just now";
    if (seconds < 60) return "${seconds}s ago";
    return "${seconds ~/ 60}m ago";
  }

  Widget _circleButton({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
    bool large = false,
  }) {
    return FloatingActionButton(
      heroTag: heroTag,
      mini: !large,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 4,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }

  // ---------- CATEGORY TABS ----------
  Widget _buildCategoryTabs() {
    final categories = [
      {"id": "all", "label": "All", "icon": Icons.apps},
      {"id": "holy", "label": "Holy Sites", "icon": Icons.mosque},
      {"id": "gate", "label": "Gates", "icon": Icons.door_front_door},
      {"id": "service", "label": "Services", "icon": Icons.medical_services},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isActive = _selectedCategory == cat["id"];
            return GestureDetector(
              onTap: () =>
                  setState(() => _selectedCategory = cat["id"] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isActive ? accentColor : Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? accentColor : Colors.white24,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      cat["icon"] as IconData,
                      size: 16,
                      color: isActive ? Colors.black : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat["label"] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- PLACE LIST (filtered by category) ----------
  Widget _buildPlaceList() {
    // Filter places by selected category
    final places = _selectedCategory == "all"
        ? PlacesData.all
        : PlacesData.all.where((p) => p.category == _selectedCategory).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 65,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: places.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final place = places[index];
            final isSelected = selectedPlace?.id == place.id;
            return _placeCard(place, isSelected);
          },
        ),
      ),
    );
  }

  Widget _placeCard(Place place, bool isSelected) {
    return GestureDetector(
      onTap: () => _navigateTo(place),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(
              _iconFor(place),
              color: isSelected ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  isSelected ? "Navigating..." : "Tap to navigate",
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.white60,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Place place) {
    switch (place.id) {
      case "kaaba":
        return Icons.navigation;
      case "saee":
        return Icons.directions_walk;
      case "mina":
        return Icons.holiday_village;
      case "arafat":
        return Icons.terrain;
      case "muzdalifah":
        return Icons.nights_stay;
      case "jamarat":
        return Icons.architecture;
      case "hospital":
        return Icons.local_hospital;
      case "zamzam":
        return Icons.water_drop;
      case "toilets":
        return Icons.wc;
      case "police":
        return Icons.local_police;
      default:
        if (place.category == "gate") return Icons.door_front_door;
        if (place.category == "holy") return Icons.mosque;
        return Icons.place;
    }
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
