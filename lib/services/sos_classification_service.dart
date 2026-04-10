import 'dart:convert';
import 'package:http/http.dart' as http;

class SOSClassificationService {
  static const String _baseUrl = 'https://noor-sos-classifier.onrender.com';

  static Future<Map<String, dynamic>> classify(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/classify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Classification failed');
      }
    } catch (e) {
      return {
        'request_type': 'general_guidance',
        'priority': 3,
        'confidence': 0.0,
        'needs_ambulance': false,
        'source': 'fallback_offline',
      };
    }
  }
}