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
    String? geminiModel,
    List<String>? learnedDates,
    int? streakDays,
    DateTime? lastLearnedAt,
    int? dailyTarget,
  }) async {
    state = state.copyWith(
      name: name,
      interests: interests,
      apiKey: apiKey,
      geminiModel: geminiModel,
      learnedDates: learnedDates,
      streakDays: streakDays,
      lastLearnedAt: lastLearnedAt,
      dailyTarget: dailyTarget,
    );
    await _storage.saveProfile(state);
  }

  Future<void> recordLearningActivity() async {
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final currentDates = List<String>.from(state.learnedDates);
    if (currentDates.contains(todayStr)) {
      await updateProfile(lastLearnedAt: now);
      return;
    }

    currentDates.add(todayStr);
    
    int newStreak = state.streakDays;
    if (state.lastLearnedAt == null) {
      newStreak = 1;
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
      final lastLearnedStr = "${state.lastLearnedAt!.year}-${state.lastLearnedAt!.month.toString().padLeft(2, '0')}-${state.lastLearnedAt!.day.toString().padLeft(2, '0')}";
      
      if (lastLearnedStr == yesterdayStr) {
        newStreak += 1;
      } else if (lastLearnedStr != todayStr) {
        newStreak = 1;
      }
    }

    await updateProfile(
      learnedDates: currentDates,
      streakDays: newStreak,
      lastLearnedAt: now,
    );
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return UserProfileNotifier(storage);
});

// 4. GeminiService Provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  final profile = ref.watch(userProfileProvider);
  return GeminiService(profile.apiKey, modelName: profile.geminiModel);
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
        if (word.id == wordId) (() {
          final now = DateTime.now();
          if (status == 1) {
            // Mastered (Quality 4)
            final reps = word.repetitions + 1;
            int interval;
            if (reps == 1) {
              interval = 1;
            } else if (reps == 2) {
              interval = 4;
            } else {
              interval = (word.intervalDays * word.easeFactor).round();
            }
            if (interval <= 0) interval = 1;

            double newEase = word.easeFactor + (0.1 - (5 - 4) * (0.08 + (5 - 4) * 0.02));
            if (newEase < 1.3) newEase = 1.3;

            return word.copyWith(
              status: 1,
              reviewedAt: now,
              nextReviewAt: now.add(Duration(days: interval)),
              intervalDays: interval,
              repetitions: reps,
              easeFactor: newEase,
            );
          } else if (status == 2) {
            // Weak (Quality 1)
            final reps = 0;
            const interval = 1;
            final newEase = (word.easeFactor - 0.2).clamp(1.3, 3.0);

            return word.copyWith(
              status: 2,
              reviewedAt: now,
              nextReviewAt: now.add(const Duration(days: interval)),
              intervalDays: interval,
              repetitions: reps,
              easeFactor: newEase,
            );
          } else {
            // Unlearned / Reset
            return word.copyWith(
              status: 0,
              reviewedAt: null,
              nextReviewAt: null,
              intervalDays: 0,
              repetitions: 0,
              easeFactor: 2.5,
            );
          }
        })()
        else
          word
    ];
    await _storage.saveWords(state);
  }

  Future<void> updateWordDetails(int wordId, {String? coreNuance, String? customExampleEn, String? customExampleJa}) async {
    state = [
      for (final word in state)
        if (word.id == wordId)
          word.copyWith(
            coreNuance: coreNuance,
            customExampleEn: customExampleEn,
            customExampleJa: customExampleJa,
          )
        else
          word
    ];
    await _storage.saveWords(state);
  }

  Future<void> toggleFavorite(int wordId) async {
    state = [
      for (final word in state)
        if (word.id == wordId)
          word.copyWith(isFavorite: !word.isFavorite)
        else
          word
    ];
    await _storage.saveWords(state);
  }

  Future<void> addWord(String spelling, String meaningJa, String? coreNuance) async {
    final nextId = state.isEmpty ? 1 : state.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;
    final newWord = Word(
      id: nextId,
      spelling: spelling,
      meaningJa: meaningJa,
      coreNuance: coreNuance,
      status: 0,
      isSystem: false,
    );
    state = [newWord, ...state];
    await _storage.saveWords(state);
  }

  Future<void> editWord(int wordId, String spelling, String meaningJa, String? coreNuance) async {
    state = [
      for (final word in state)
        if (word.id == wordId && !word.isSystem)
          word.copyWith(
            spelling: spelling,
            meaningJa: meaningJa,
            coreNuance: coreNuance,
          )
        else
          word
    ];
    await _storage.saveWords(state);
  }

  Future<void> deleteWord(int wordId) async {
    state = [
      for (final word in state)
        if (word.id != wordId || word.isSystem) word
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
          isSystem: false,
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
