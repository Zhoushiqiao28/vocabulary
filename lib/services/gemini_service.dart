import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
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
        httpClient: CorsProxyClient(),
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
      final plainModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        httpClient: CorsProxyClient(),
      );
      final content = [Content.text(prompt)];
      final response = await plainModel.generateContent(content);
      return response.text ?? '解説を生成できませんでした。';
    } catch (e) {
      return 'エラーが発生したため、ニュアンス解説を読み込めませんでした。';
    }
  }

  // 3. Send Chat Message & Correction
  Future<Map<String, dynamic>> sendChatMessage(
      List<ChatMessage> history, String userMsg, List<Word> targetWords) async {
    final targetWordsInfo = targetWords.map((w) {
      final statusStr = w.status == 2 ? '覚えてない(苦手)' : (w.status == 0 ? '未学習' : '要復習');
      return '- ${w.spelling} (意味: ${w.meaningJa}, 優先度: $statusStr)';
    }).join('\n');

    if (!isAvailable) {
      final wordSpellingList = targetWords.map((e) => e.spelling).join(', ');
      return {
        'ai_reply': 'Hello! Let\'s talk about your day, or anything you like. Try to use words like: $wordSpellingList.',
        'needs_correction': false,
        'corrected_text': null,
        'explanation': null,
      };
    }

    final historyText = history.map((e) => "${e.role == 'user' ? 'User' : 'AI'}: ${e.text}").join('\n');

    final prompt = '''
You are an expert AI English tutor. Your primary goal is to help the user naturally learn and memorize the target vocabulary words listed below during the chat.

TARGET WORDS FOR THIS SESSION:
$targetWordsInfo

YOUR INSTRUCTIONS:
1. Conduct a natural, friendly chat in English.
2. In your response ("ai_reply"), you MUST naturally use 1 or 2 target words from the list, OR ask questions that encourage the user to use them.
3. If the user uses any target words correctly (even in different tenses/plurals), praise them.
4. Critically analyze the user's latest input ("User (Latest)").
5. If the user's sentence has spelling/grammar errors or sounds unnatural, set "needs_correction" to true, write the "corrected_text" and provide a brief explanation in Japanese ("explanation"). Otherwise, set "needs_correction" to false.

CONVERSATION HISTORY:
$historyText
User (Latest): $userMsg

Analyze the User's latest input. Respond in JSON format:
{
  "ai_reply": "Your natural, encouraging reply in English (1-2 sentences). Naturally incorporate or prompt for target words.",
  "needs_correction": true/false,
  "original_text": "$userMsg",
  "corrected_text": "Corrected English sentence (null if no correction needed).",
  "explanation": "Japanese explanation for correction (null if no correction needed)."
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

// Custom HTTP Client to proxy request in web to bypass CORS limitations
class CorsProxyClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (kIsWeb) {
      final proxyUrl = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(request.url.toString())}');
      final newRequest = http.StreamedRequest(request.method, proxyUrl);
      newRequest.headers.addAll(request.headers);
      
      request.finalize().listen(
        newRequest.sink.add,
        onError: newRequest.sink.addError,
        onDone: newRequest.sink.close,
        cancelOnError: true,
      );
      return _inner.send(newRequest);
    }
    return _inner.send(request);
  }
}
