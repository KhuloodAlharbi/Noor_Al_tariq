import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

// This represents one crowded area on the map.
// Now includes "best time to visit" info (FR8.5).
class CrowdZone {
  final String id;
  final String nameKey;
  final LatLng center;
  final double radius;
  final double density; // 0.0 = empty, 1.0 = packed
  final String bestTime; // e.g. "2:00 AM - 4:00 AM"
  final String bestTimeNote; // e.g. "Least crowded after Tahajjud"

  const CrowdZone({
    required this.id,
    required this.nameKey,
    required this.center,
    required this.radius,
    required this.density,
    this.bestTime = "",
    this.bestTimeNote = "",
  });

  String get translatedName => nameKey.tr();

  Color get color {
    if (density >= 0.7) return Colors.red;
    if (density >= 0.4) return Colors.orange;
    return Colors.green;
  }

  String get levelKey {
    if (density >= 0.7) return "map.crowded";
    if (density >= 0.4) return "map.medium";
    return "map.safe";
  }

  String get levelLabel => levelKey.tr();
}
