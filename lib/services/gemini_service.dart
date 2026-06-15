import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  // API key must be set by the user in app Settings → Gemini API Key
  static const String defaultKey = "";

  Future<String> askChatbot({
    required String diseaseName,
    required List<Map<String, String>> history,
    required String message,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? defaultKey;

    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey");

    // Build the request contents with history
    List<Map<String, dynamic>> contents = [];

    // Add history in Gemini format: {"role": "user"|"model", "parts": [{"text": "message"}]}
    for (var chat in history) {
      contents.add({
        "role": chat["role"] == "user" ? "user" : "model",
        "parts": [
          {"text": chat["message"]}
        ]
      });
    }

    // Add current user message
    contents.add({
      "role": "user",
      "parts": [
        {"text": message}
      ]
    });

    final systemInstruction = {
      "parts": [
        {
          "text": "You are a professional rice crop agronomist chatbot helping a farmer whose crop has been diagnosed with the disease: '$diseaseName'.\n"
              "CRITICAL RULE: You must ONLY answer questions, provide information, or discuss matters directly related to '$diseaseName' (its symptoms, causes, treatments, prevention, recommended agricultural chemicals, etc.).\n"
              "If the user asks about anything else (e.g., other unrelated diseases, general knowledge, programming, math, history, or unrelated topics), you must politely decline and state that you are a specialized assistant for '$diseaseName' and can only answer questions related to it."
        }
      ]
    };

    final body = jsonEncode({
      "contents": contents,
      "systemInstruction": systemInstruction,
      "generationConfig": {
        "temperature": 0.3,
        "maxOutputTokens": 800,
      }
    });

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      try {
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      } catch (e) {
        throw Exception("Failed to parse response: $e\nResponse body: ${response.body}");
      }
    } else {
      throw Exception("API Error (Status Code: ${response.statusCode}):\n${response.body}");
    }
  }
}
