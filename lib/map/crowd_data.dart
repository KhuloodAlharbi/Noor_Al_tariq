import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'crowd_zone.dart';

// FAKE crowd data for now — just so we can SEE the heatmap working.
// In Step 3, we'll replace this with a real API call to our FastAPI server.
//
// Density is a number from 0.0 (empty) to 1.0 (packed).
class CrowdData {
  static const List<CrowdZone> sampleZones = [
    // Around the Kaaba — usually very crowded
    CrowdZone(
      id: "mataf",
      nameKey: "crowd_zones.mataf.name",
      center: LatLng(21.4225, 39.8262),
      radius: 80,
      density: 0.9,
    ),
    
    // Saee area — medium busy
    CrowdZone(
      id: "saee_zone",
      nameKey: "crowd_zones.saee_zone.name",
      center: LatLng(21.4220, 39.8280),
      radius: 60,
      density: 0.55, // YELLOW
    ),

    // King Abdulaziz Gate — light crowd
    CrowdZone(
      id: "gate_zone",
      nameKey: "crowd_zones.gate_zone.name",
      center: LatLng(21.4220, 39.8275),
      radius: 50,
      density: 0.3, // GREEN
    ),

    // Outer courtyard — very calm
    CrowdZone(
      id: "outer",
      nameKey: "crowd_zones.outer.name",
      center: LatLng(21.4250, 39.8240),
      radius: 70,
      density: 0.2, // GREEN
    ),
  ];
}
