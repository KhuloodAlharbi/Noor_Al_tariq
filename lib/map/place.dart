import 'package:google_maps_flutter/google_maps_flutter.dart';

// This class represents one important place on the map.
// Categories: "holy", "gate", "service"
class Place {
  final String id;
  final String name;
  final String description;
  final String category; // "holy", "gate", or "service"
  final LatLng location;

  const Place({
    required this.id,
    required this.name,
    required this.description,
    this.category = "service",
    required this.location,
  });
}
