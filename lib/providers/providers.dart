import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';

// 1. SharedPreferences Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

// 2. StorageService Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return StorageService(prefs);
});

// 3. UserProfile Provider (StateNotifier)
class UserProfileNotifier extends StateNotifier<UserProfile> {
  final StorageService _storage;

  UserProfileNotifier(this._storage) : super(_storage.getProfile());

  Future<void> updateProfile({
    String? name,
    List<String>? interests,
    String? apiKey,
    int? streakDays,
    DateTime? lastLearnedAt,
  }) async {
    state = state.copyWith(
      name: name,
      interests: interests,
      apiKey: apiKey,
      streakDays: streakDays,
      lastLearnedAt: lastLearnedAt,
    );
    await _storage.saveProfile(state);
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return UserProfileNotifier(storage);
});

// 4. GeminiService Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final profile = ref.watch(userProfileProvider);
  return GeminiService(profile.apiKey);
});

// 5. WordList Provider (StateNotifier)
class WordListNotifier extends StateNotifier<List<Word>> {
  final StorageService _storage;

  WordListNotifier(this._storage) : super([]) {
    loadWords();
  }

  Future<void> loadWords() async {
    final words = await _storage.getWords();
    state = words;
  }

  Future<void> updateWordStatus(int wordId, int status) async {
    state = [
      for (final word in state)
        if (word.id == wordId)
          word.copyWith(status: status, reviewedAt: DateTime.now())
        else
          word
    ];
    await _storage.saveWords(state);
  }

  Future<void> updateWordDetails(int wordId, {String? coreNuance, String? customExampleEn, String? customExampleJa}) async {
    state = [
      for (final word in state)
        if (word.id == wordId)
          Word(
            id: word.id,
            spelling: word.spelling,
            meaningJa: word.meaningJa,
            status: word.status,
            reviewedAt: word.reviewedAt,
            coreNuance: coreNuance ?? word.coreNuance,
            customExampleEn: customExampleEn ?? word.customExampleEn,
            customExampleJa: customExampleJa ?? word.customExampleJa,
          )
        else
          word
    ];
    await _storage.saveWords(state);
  }

  // Import Scanned Words
  Future<void> importScannedWords(List<Map<String, String>> scannedWords) async {
    final List<Word> updatedList = List.from(state);
    int nextId = updatedList.isEmpty ? 1 : updatedList.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

    for (var scanned in scannedWords) {
      final spelling = scanned['spelling']!;
      final meaningJa = scanned['meaning_ja']!;

      // Check if word already exists
      final exists = updatedList.any((e) => e.spelling.toLowerCase() == spelling.toLowerCase());
      if (!exists) {
        updatedList.insert(0, Word(
          id: nextId++,
          spelling: spelling,
          meaningJa: meaningJa,
          status: 0,
        ));
      }
    }
    state = updatedList;
    await _storage.saveWords(state);
  }
}

final wordListProvider = StateNotifierProvider<WordListNotifier, List<Word>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return WordListNotifier(storage);
});

// 6. Chat Provider (StateNotifier)
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final StorageService _storage;
  final GeminiService _gemini;
  List<Word> _targetWords = [];

  ChatNotifier(this._storage, this._gemini) : super([]) {
    _loadHistory();
  }

  List<Word> get targetWords => _targetWords;

  void setTargetWords(List<Word> words) {
    _targetWords = words;
  }

  void _loadHistory() {
    state = _storage.getChatHistory("ai_voca_chat");
  }

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(role: 'user', text: text, sentAt: DateTime.now());
    state = [...state, userMsg];
    await _storage.saveChatHistory("ai_voca_chat", state);

    // Call Gemini API for response and correction, passing target words
    final response = await _gemini.sendChatMessage(state, text, _targetWords);

    final aiMsg = ChatMessage(
      role: 'model',
      text: response['ai_reply'] ?? '',
      needsCorrection: response['needs_correction'] ?? false,
      correctedText: response['corrected_text'],
      explanation: response['explanation'],
      sentAt: DateTime.now(),
    );

    state = [...state, aiMsg];
    await _storage.saveChatHistory("ai_voca_chat", state);
  }

  Future<void> clearHistory() async {
    state = [];
    await _storage.saveChatHistory("ai_voca_chat", []);
  }
}

// Global provider for AI Voca Chat
final aiVocaChatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final gemini = ref.watch(geminiServiceProvider);
  return ChatNotifier(storage, gemini);
});
