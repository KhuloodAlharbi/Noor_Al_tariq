import 'dart:convert';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000";

  Future<String> askChatbot(String question) async {
    final url = Uri.parse("$baseUrl/chat");

    print("Sending to API: $question");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"question": question}),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"] ?? "No answer";
    } else {
      return "Error: ${response.statusCode}";
    }
  }
}
