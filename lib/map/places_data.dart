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
      name: "Masjid al-Haram",
      description: "The Holy Kaaba",
      category: "holy",
      location: LatLng(21.4225, 39.8262),
    ),
    Place(
      id: "saee",
      name: "Saee (Safa & Marwah)",
      description: "The Sa'i walking path",
      category: "holy",
      location: LatLng(21.4243, 39.8283),
    ),
    Place(
      id: "mina",
      name: "Mina",
      description: "Tent city for Hajj days",
      category: "holy",
      location: LatLng(21.4133, 39.8933),
    ),
    Place(
      id: "arafat",
      name: "Mount Arafat",
      description: "Day of Arafah gathering",
      category: "holy",
      location: LatLng(21.3549, 39.9842),
    ),
    Place(
      id: "muzdalifah",
      name: "Muzdalifah",
      description: "Night stay after Arafat",
      category: "holy",
      location: LatLng(21.3892, 39.9290),
    ),
    Place(
      id: "jamarat",
      name: "Jamarat Bridge",
      description: "Stoning of the Devil",
      category: "holy",
      location: LatLng(21.4197, 39.8728),
    ),

    // --- GATES ---
    Place(
      id: "gate_abdulaziz",
      name: "King Abdulaziz Gate",
      description: "Main entrance - Gate 1",
      category: "gate",
      location: LatLng(21.4220, 39.8275),
    ),
    Place(
      id: "gate_fahd",
      name: "King Fahd Gate",
      description: "Northern entrance",
      category: "gate",
      location: LatLng(21.4260, 39.8262),
    ),
    Place(
      id: "gate_umrah",
      name: "Umrah Gate",
      description: "Eastern entrance",
      category: "gate",
      location: LatLng(21.4230, 39.8300),
    ),

    // --- SERVICES ---
    Place(
      id: "toilets",
      name: "Public Restrooms",
      description: "Facilities near Gate 1",
      category: "service",
      location: LatLng(21.4235, 39.8268),
    ),
    Place(
      id: "police",
      name: "Police Station",
      description: "Security & lost items",
      category: "service",
      location: LatLng(21.4250, 39.8250),
    ),
    Place(
      id: "hospital",
      name: "Ajyad Hospital",
      description: "Nearest hospital to Haram",
      category: "service",
      location: LatLng(21.4193, 39.8248),
    ),
    Place(
      id: "zamzam",
      name: "Zamzam Water",
      description: "Zamzam water stations",
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
