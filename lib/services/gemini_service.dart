import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiService {
  final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.5-flash-lite',
  );

    Future<String> generateText(String prompt) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 60));
        return response.text ?? '';
      } on FirebaseAIException {
        if (attempt >= 3) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) => GeminiService());