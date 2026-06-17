import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/models.dart';

class GeminiService {
  final String _apiKey;
  GenerativeModel? _model;

  GeminiService(this._apiKey) {
    if (_apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );
    }
  }

  bool get isAvailable => _model != null;

  // 1. Generate Custom Example
  Future<Map<String, String>> generateCustomExample(
      String word, String meaning, List<String> interests) async {
    if (!isAvailable) {
      // Return mock data if API key is not configured
      return {
        'sentence_en': 'He had to follow the strict F1 safety car rules during the race.',
        'sentence_ja': '彼はレース中、厳格なF1セーフティカーの規則に従わなければならなかった。'
      };
    }

    final prompt = '''
You are an expert English teacher. Generate an English example sentence and its Japanese translation using the target word.
The sentence MUST be highly contextualized to the user's specific interests: ${interests.join(', ')}.

TARGET_WORD: $word (Meaning: $meaning)

Generate a JSON object with the following structure:
{
  "sentence_en": "Example sentence based on user interests.",
  "sentence_ja": "日本語訳。"
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      final json = jsonDecode(response.text ?? '{}');
      return {
        'sentence_en': json['sentence_en'] ?? '',
        'sentence_ja': json['sentence_ja'] ?? '',
      };
    } catch (e) {
      return {
        'sentence_en': 'Failed to generate example due to network error.',
        'sentence_ja': 'ネットワークエラーのため例文を生成できませんでした。'
      };
    }
  }

  // 2. Get Word Nuance / Origin
  Future<String> getWordNuance(String word, String meaning) async {
    if (!isAvailable) {
      return '【コアイメージ】\n「$word」は「何かの後ろをついていく」が核心のイメージです。そこから、ルールに従う、人の言葉を理解する（ついていく）などの意味に広がります。';
    }

    final prompt = '''
You are an expert etymologist and English teacher. Explain the origin (etymology), core nuance (image), and usage distinction of the word: "$word" (meaning: "$meaning") in Japanese.
Format the output with clear bullet points or section headers like:
【語源】...
【コアイメージ】...
【使い分けのポイント】...
Keep it concise and beautiful for a mobile app card detail. Do not return JSON, just plain text.
''';

    try {
      final plainModel = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final content = [Content.text(prompt)];
      final response = await plainModel.generateContent(content);
      return response.text ?? '解説を生成できませんでした。';
    } catch (e) {
      return 'エラーが発生したため、ニュアンス解説を読み込めませんでした。';
    }
  }

  // 3. Send Chat Message & Correction
  Future<Map<String, dynamic>> sendChatMessage(
      List<ChatMessage> history, String userMsg, String targetWord) async {
    if (!isAvailable) {
      return {
        'ai_reply': 'That sounds interesting! Have you ever encountered such a situation before?',
        'needs_correction': false,
        'corrected_text': null,
        'explanation': null,
      };
    }

    final historyText = history.map((e) => "${e.role == 'user' ? 'User' : 'AI'}: ${e.text}").join('\n');

    final prompt = '''
You are an AI conversation partner for English learners.
The user is trying to practice the target word: "$targetWord".
Engage in a natural dialogue. However, you must also analyze the user's latest input for grammatical correctness and naturalness.

CONVERSATION HISTORY:
$historyText
User (Latest): $userMsg

Analyze the User's latest input. Respond in JSON format:
{
  "ai_reply": "Your natural conversational response in English (keep it to 1-2 sentences).",
  "needs_correction": true/false,
  "original_text": "$userMsg",
  "corrected_text": "The corrected version of the user input (null if no correction needed).",
  "explanation": "Brief explanation of why it was corrected in Japanese (null if no correction needed)."
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return jsonDecode(response.text ?? '{}');
    } catch (e) {
      return {
        'ai_reply': 'Sorry, I had trouble processing that message. Could you say it again?',
        'needs_correction': false,
        'corrected_text': null,
        'explanation': null,
      };
    }
  }

  // 4. Scan text and extract words
  Future<List<Map<String, String>>> scanTextForWords(String text) async {
    if (!isAvailable) {
      return [
        {'spelling': 'encounter', 'meaning_ja': '〜に遭遇する'},
        {'spelling': 'examine', 'meaning_ja': '〜を調査する'},
      ];
    }

    final prompt = '''
Analyze the following English text. Extract up to 5 important vocabulary words (especially useful for English learners, verbs/nouns/adjectives).
For each word, provide its Japanese translation.

TEXT:
$text

Respond in JSON format:
{
  "words": [
    {
      "spelling": "word",
      "meaning_ja": "日本語の意味"
    }
  ]
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      final decoded = jsonDecode(response.text ?? '{}');
      final List<dynamic> wordsList = decoded['words'] ?? [];
      return wordsList.map((e) => {
        'spelling': (e['spelling'] as String).toLowerCase().trim(),
        'meaning_ja': e['meaning_ja'] as String,
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
