import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageService {
  static const String _keyProfile = 'user_profile';
  static const String _keyWords = 'vocabulary_words';
  static const String _keyChat = 'chat_messages';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  // Profile Storage
  UserProfile getProfile() {
    final raw = _prefs.getString(_keyProfile);
    if (raw == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }

  // Vocabulary Storage
  Future<List<Word>> getWords() async {
    final raw = _prefs.getString(_keyWords);
    if (raw == null) {
      // SharedPreferences is empty. Load seed data from assets!
      return await _loadSeedWords();
    }
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => Word.fromJson(e)).toList();
  }

  Future<void> saveWords(List<Word> words) async {
    await _prefs.setString(_keyWords, jsonEncode(words.map((e) => e.toJson()).toList()));
  }

  // Load Seed Words from assets/wordsdata.json
  Future<List<Word>> _loadSeedWords() async {
    try {
      final String jsonStr = await rootBundle.loadString('assets/wordsdata.json');
      final List<dynamic> list = jsonDecode(jsonStr);
      final List<Word> words = [];
      for (var e in list) {
        words.add(Word(
          id: e['id'],
          spelling: e['spelling'],
          meaningJa: e['meaning_ja'], // matching python format key name
          status: 0,
          isSystem: true,
        ));
      }
      await saveWords(words); // Cache into SharedPreferences
      return words;
    } catch (e) {
      // Fallback
      return [
        Word(id: 1, spelling: 'follow', meaningJa: '〜の後に続く、〜に従う', isSystem: true),
        Word(id: 2, spelling: 'consider', meaningJa: '〜を考慮する', isSystem: true),
      ];
    }
  }

  // Chat History Storage
  List<ChatMessage> getChatHistory(String wordSpelling) {
    final raw = _prefs.getString('${_keyChat}_$wordSpelling');
    if (raw == null) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<void> saveChatHistory(String wordSpelling, List<ChatMessage> messages) async {
    await _prefs.setString(
      '${_keyChat}_$wordSpelling',
      jsonEncode(messages.map((e) => e.toJson()).toList()),
    );
  }
}
