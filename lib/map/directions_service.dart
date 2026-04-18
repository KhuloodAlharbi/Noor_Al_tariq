import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// This class calculates a route between two points WITHOUT calling Google.
// It uses simple math (the Haversine formula via Geolocator) to find the
// straight-line distance, then estimates walking time based on average
// pilgrim walking speed (5 km/h).
//
// Note for the report: this is a development-phase implementation.
// In production, the same interface can call Google Directions API
// without changing any other file in the project.
class DirectionsService {
  // Average walking speed in meters per second (~5 km/h, normal pace)
  static const double _walkingSpeedMps = 1.4;

  static Future<DirectionsResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Tiny artificial delay so the loading spinner shows briefly
    // (makes the UX feel like a real network call)
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      // Calculate straight-line distance in meters
      final distanceMeters = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Estimate walking time in seconds
      final durationSeconds = (distanceMeters / _walkingSpeedMps).round();

      // Build a route with a few intermediate points for a smoother line
      final points = _buildSmoothLine(origin, destination);

      return DirectionsResult(
        points: points,
        distanceText: _formatDistance(distanceMeters),
        durationText: _formatDuration(durationSeconds),
        distanceMeters: distanceMeters.round(),
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      print("DirectionsService error: $e");
      return null;
    }
  }

  // Make the line look nicer by adding intermediate points
  // (a single straight line of 2 points still works, but more points = smoother)
  static List<LatLng> _buildSmoothLine(LatLng origin, LatLng destination) {
    const int segments = 20;
    final List<LatLng> points = [];
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final lat =
          origin.latitude + (destination.latitude - origin.latitude) * t;
      final lng =
          origin.longitude + (destination.longitude - origin.longitude) * t;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  // Format meters into a nice human-readable text like "850 m" or "1.2 km"
  static String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()} m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
  }

  // Format seconds into "5 min" or "1 h 20 min"
  static String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    } else {
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;
      return "$hours h $remaining min";
    }
  }
}

// A simple data holder for the route info — same shape as before,
// so map_page.dart doesn't need to change at all!
class DirectionsResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;
  final int distanceMeters;
  final int durationSeconds;

  DirectionsResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
