import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'place.dart';

// All the important places for pilgrims.
// Organized by category for easy filtering.
// To add a new place, just add one more Place(...) entry.
class PlacesData {
  static const List<Place> all = [
    // --- HOLY SITES ---
    Place(
      id: "kaaba",
      nameKey: "places.kaaba.name",
      descriptionKey: "places.kaaba.description",
      category: "holy",
      location: LatLng(21.4225, 39.8262),
    ),
    Place(
      id: "saee",
      nameKey: "places.saee.name",
      descriptionKey: "places.saee.description",
      category: "holy",
      location: LatLng(21.4243, 39.8283),
    ),
    Place(
      id: "mina",
      nameKey: "places.mina.name",
      descriptionKey: "places.mina.description",
      category: "holy",
      location: LatLng(21.4133, 39.8933),
    ),
    Place(
      id: "arafat",
      nameKey: "places.arafat.name",
      descriptionKey: "places.arafat.description",
      category: "holy",
      location: LatLng(21.3549, 39.9842),
    ),
    Place(
      id: "muzdalifah",
      nameKey: "places.muzdalifah.name",
      descriptionKey: "places.muzdalifah.description",
      category: "holy",
      location: LatLng(21.3892, 39.9290),
    ),
    Place(
      id: "jamarat",
      nameKey: "places.jamarat.name",
      descriptionKey: "places.jamarat.description",
      category: "holy",
      location: LatLng(21.4197, 39.8728),
    ),
    // --- GATES ---
    Place(
      id: "gate_abdulaziz",
      nameKey: "places.gate_abdulaziz.name",
      descriptionKey: "places.gate_abdulaziz.description",
      category: "gate",
      location: LatLng(21.4220, 39.8275),
    ),
    Place(
      id: "gate_fahd",
      nameKey: "places.gate_fahd.name",
      descriptionKey: "places.gate_fahd.description",
      category: "gate",
      location: LatLng(21.4260, 39.8262),
    ),
    Place(
      id: "gate_umrah",
      nameKey: "places.gate_umrah.name",
      descriptionKey: "places.gate_umrah.description",
      category: "gate",
      location: LatLng(21.4230, 39.8300),
    ),
    
    // --- SERVICES ---
    Place(
      id: "toilets",
      nameKey: "places.toilets.name",
      descriptionKey: "places.toilets.description",
      category: "service",
      location: LatLng(21.4235, 39.8268),
    ),
    Place(
      id: "police",
      nameKey: "places.police.name",
      descriptionKey: "places.police.description",
      category: "service",
      location: LatLng(21.4250, 39.8250),
    ),
    Place(
      id: "hospital",
      nameKey: "places.hospital.name",
      descriptionKey: "places.hospital.description",
      category: "service",
      location: LatLng(21.4193, 39.8248),
    ),
    Place(
      id: "zamzam",
      nameKey: "places.zamzam.name",
      descriptionKey: "places.zamzam.description",
      category: "service",
      location: LatLng(21.4228, 39.8265),
    ),
  ];

  // Get a place by its id
  static Place? getById(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  // Get places by category
  static List<Place> byCategory(String category) {
    return all.where((p) => p.category == category).toList();
  }
}
