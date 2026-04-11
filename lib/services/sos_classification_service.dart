import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SOSClassificationService {
  static const String _baseUrl = 'https://noor-sos-classifier.onrender.com';

  static Future<Map<String, dynamic>> classify(String text) async {
    try {
      debugPrint('SOS_API: Calling $_baseUrl/classify with text: $text');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/classify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 60));

      debugPrint('SOS_API: Response status: ${response.statusCode}');
      debugPrint('SOS_API: Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Classification failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('SOS_API ERROR: $e');
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
