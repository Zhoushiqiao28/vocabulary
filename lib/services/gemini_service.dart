import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class GeminiService {
  final String _apiKey;
  final String _modelName;
  GenerativeModel? _model;

  GeminiService(this._apiKey, {String modelName = 'gemini-2.5-flash'})
      : _modelName = modelName.isNotEmpty ? modelName : 'gemini-2.5-flash' {
    if (_apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: _modelName,
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
        'sentence_en': 'API Error: ${e.toString()}',
        'sentence_ja': '例文の生成に失敗しました。APIキーの有効性や、利用制限エラー、ネットワーク環境を確認してください。'
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
        model: _modelName,
        apiKey: _apiKey,
        httpClient: CorsProxyClient(),
      );
      final content = [Content.text(prompt)];
      final response = await plainModel.generateContent(content);
      return response.text ?? '解説を生成できませんでした。';
    } catch (e) {
      return 'エラーが発生したため、ニュアンス解説を読み込めませんでした。詳細: ${e.toString()}';
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
        'ai_reply': 'Sorry, I had trouble processing that message. Error: ${e.toString()}',
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

  // 5. Test Connection to Gemini API
  Future<Map<String, dynamic>> testConnection(String apiKey) async {
    if (apiKey.isEmpty) {
      return {
        'success': false,
        'message': 'APIキーが入力されていません。',
        'advice': '設定画面のAPIキー入力欄に有効なキーを入力してください。'
      };
    }

    final client = CorsProxyClient();
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');

    try {
      final response = await client.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> modelsList = data['models'] ?? [];
        final modelNames = modelsList.map((m) => m['name'] as String).toList();
        
        final hasFlash = modelNames.any((name) => name.contains('gemini-1.5-flash'));
        
        // Determine the best available model for general content generation
        String bestModel = 'gemini-2.5-flash';
        final normalizedNames = modelNames.map((e) => e.replaceFirst('models/', '')).toList();
        
        if (normalizedNames.contains('gemini-2.5-flash')) {
          bestModel = 'gemini-2.5-flash';
        } else if (normalizedNames.contains('gemini-2.0-flash')) {
          bestModel = 'gemini-2.0-flash';
        } else if (normalizedNames.contains('gemini-1.5-flash')) {
          bestModel = 'gemini-1.5-flash';
        } else {
          final flashModel = normalizedNames.firstWhere(
            (m) => m.toLowerCase().contains('flash'),
            orElse: () => normalizedNames.isNotEmpty ? normalizedNames.first : 'gemini-2.5-flash',
          );
          bestModel = flashModel;
        }
        
        return {
          'success': true,
          'models': modelNames,
          'hasFlash': hasFlash,
          'bestModel': bestModel,
          'message': '接続成功！利用可能なモデルが見つかりました。',
          'advice': 'APIキーは正常に動作しています。AI機能を利用可能です。',
        };
      } else {
        String errorMsg = 'HTTP ${response.statusCode}';
        String advice = 'APIキーが正しくないか、Google AI Studioの設定に問題があります。';
        
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            final innerError = errorData['error'];
            errorMsg = innerError['message'] ?? errorMsg;
            final status = innerError['status'] ?? '';
            
            if (status == 'INVALID_ARGUMENT' || errorMsg.contains('API key not valid')) {
              advice = 'APIキーが無効です。コピー＆ペーストの際に余分なスペースや文字が入っていないか、または新しくキーを作成し直してください。';
            } else if (status == 'PERMISSION_DENIED') {
              if (errorMsg.contains('disabled') || errorMsg.contains('Generative Language API')) {
                advice = 'GCPプロジェクトで「Generative Language API」が有効になっていません。Google AI Studio (https://aistudio.google.com/) で「Create API Key in new project」を選択して新しいキーを作成するか、Google Cloud ConsoleでAPIを有効にしてください。';
              } else {
                advice = 'アクセス権限がありません。APIキーの制限設定（IP制限やAPI制限）を確認してください。';
              }
            }
          }
        } catch (_) {}
        
        return {
          'success': false,
          'message': '接続失敗: $errorMsg',
          'advice': advice,
          'rawBody': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': '通信エラー: ${e.toString()}',
        'advice': 'ネットワーク接続を確認するか、CORSプロキシサーバーの一時的な障害の可能性があります。',
      };
    }
  }
}

// Custom HTTP Client to proxy request in web to bypass CORS limitations
class CorsProxyClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (kIsWeb) {
      try {
        final proxyUrl = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(request.url.toString())}');
        
        // Read body to bytes to avoid chunked transfer issues on Web
        final bytes = await request.finalize().toBytes();
        
        final newRequest = http.Request(request.method, proxyUrl);
        newRequest.headers.addAll(request.headers);
        
        // Host header must be removed/rewritten for the proxy, otherwise it rejects
        newRequest.headers.remove('host');
        newRequest.headers.remove('Host');
        
        newRequest.bodyBytes = bytes;
        return await _inner.send(newRequest);
      } catch (e) {
        // Do not fallback to direct request because request is already finalized
        // and direct request will fail with CORS anyway. Just rethrow.
        rethrow;
      }
    }
    return _inner.send(request);
  }
}
