import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'crowd_zone.dart';
import 'crowd_data.dart';

// Fetches live crowd data from our Python FastAPI backend.
class CrowdApiService {
  // Android emulator -> 10.0.2.2 | iOS -> localhost | Real phone -> your laptop IP
  static const String baseUrl = "http://10.0.2.2:8001";

  static Future<List<CrowdZone>> fetchCrowdZones() async {
    final url = Uri.parse("$baseUrl/crowd_density");

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        debugPrint("Crowd API returned status ${response.statusCode}");
        return CrowdData.sampleZones;
      }

      final data = jsonDecode(response.body);
      final List<dynamic> zonesJson = data["zones"];

      final zones = zonesJson.map((z) {
        final id = z["id"] as String;

        return CrowdZone(
          id: id,
          nameKey: "crowd_zones.$id.name",
          center: LatLng(z["lat"], z["lng"]),
          radius: (z["radius"] as num).toDouble(),
          density: (z["density"] as num).toDouble(),
          bestTime: z["best_time"] ?? "",
          bestTimeNote: z["best_time_note"] ?? "",
        );
      }).toList();

      debugPrint("✅ Fetched ${zones.length} live crowd zones from API");
      return zones;
    } catch (e) {
      debugPrint("⚠️ Could not reach crowd API ($e). Using fallback data.");
      return CrowdData.sampleZones;
    }
  }
}
