import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Your backend running on emulator
  static const String baseUrl = "http://10.0.2.2:8000";

  Future<String> askChatbot(String question) async {
    // Debug prints
    print("🔵 Sending question: $question");
    print("🔵 URL: $baseUrl/chat");

    final url = Uri.parse("$baseUrl/chat");

    final response = await http.post(
      url,
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"question": question}),
    );

    // Debug prints for response
    print("🟡 Status code: ${response.statusCode}");
    print("🟢 Response: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["answer"] ?? "No answer";
    } else {
      return "Error: ${response.statusCode}\nResponse: ${response.body}";
    }
  }
}
