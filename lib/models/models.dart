class Word {
  final int id;
  final String spelling;
  final String meaningJa;
  String? coreNuance;
  int status; // 0: 未学習, 1: 覚えた, 2: 覚えてない
  String? customExampleEn;
  String? customExampleJa;
  DateTime? reviewedAt;
  bool isFavorite;
  final bool isSystem;

  Word({
    required this.id,
    required this.spelling,
    required this.meaningJa,
    this.coreNuance,
    this.status = 0,
    this.customExampleEn,
    this.customExampleJa,
    this.reviewedAt,
    this.isFavorite = false,
    this.isSystem = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'spelling': spelling,
        'meaningJa': meaningJa,
        'coreNuance': coreNuance,
        'status': status,
        'customExampleEn': customExampleEn,
        'customExampleJa': customExampleJa,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'isFavorite': isFavorite,
        'isSystem': isSystem,
      };

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'],
        spelling: json['spelling'],
        meaningJa: json['meaningJa'],
        coreNuance: json['coreNuance'],
        status: json['status'] ?? 0,
        customExampleEn: json['customExampleEn'],
        customExampleJa: json['customExampleJa'],
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'])
            : null,
        isFavorite: json['isFavorite'] ?? false,
        isSystem: json['isSystem'] ?? false,
      );

  Word copyWith({
    String? spelling,
    String? meaningJa,
    int? status,
    String? coreNuance,
    String? customExampleEn,
    String? customExampleJa,
    DateTime? reviewedAt,
    bool? isFavorite,
    bool? isSystem,
  }) {
    return Word(
      id: id,
      spelling: spelling ?? this.spelling,
      meaningJa: meaningJa ?? this.meaningJa,
      coreNuance: coreNuance ?? this.coreNuance,
      status: status ?? this.status,
      customExampleEn: customExampleEn ?? this.customExampleEn,
      customExampleJa: customExampleJa ?? this.customExampleJa,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final bool needsCorrection;
  final String? correctedText;
  final String? explanation;
  final DateTime sentAt;

  ChatMessage({
    required this.role,
    required this.text,
    this.needsCorrection = false,
    this.correctedText,
    this.explanation,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'needsCorrection': needsCorrection,
        'correctedText': correctedText,
        'explanation': explanation,
        'sentAt': sentAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'],
        text: json['text'],
        needsCorrection: json['needsCorrection'] ?? false,
        correctedText: json['correctedText'],
        explanation: json['explanation'],
        sentAt: DateTime.parse(json['sentAt']),
      );
}

class UserProfile {
  final String name;
  final List<String> interests;
  final String apiKey;
  final String geminiModel;
  final List<String> learnedDates;
  final int streakDays;
  final DateTime? lastLearnedAt;
  final int dailyTarget;

  UserProfile({
    this.name = 'User',
    this.interests = const ['Technology', 'F1', 'Space Rover'],
    this.apiKey = '',
    this.geminiModel = 'gemini-2.5-flash',
    this.learnedDates = const [],
    this.streakDays = 0,
    this.lastLearnedAt,
    this.dailyTarget = 10,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'interests': interests,
        'apiKey': apiKey,
        'geminiModel': geminiModel,
        'learnedDates': learnedDates,
        'streakDays': streakDays,
        'lastLearnedAt': lastLearnedAt?.toIso8601String(),
        'dailyTarget': dailyTarget,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? 'User',
        interests: List<String>.from(json['interests'] ?? []),
        apiKey: json['apiKey'] ?? '',
        geminiModel: json['geminiModel'] ?? 'gemini-2.5-flash',
        learnedDates: List<String>.from(json['learnedDates'] ?? []),
        streakDays: json['streakDays'] ?? 0,
        lastLearnedAt: json['lastLearnedAt'] != null
            ? DateTime.parse(json['lastLearnedAt'])
            : null,
        dailyTarget: json['dailyTarget'] ?? 10,
      );

  UserProfile copyWith({
    String? name,
    List<String>? interests,
    String? apiKey,
    String? geminiModel,
    List<String>? learnedDates,
    int? streakDays,
    DateTime? lastLearnedAt,
    int? dailyTarget,
  }) {
    return UserProfile(
      name: name ?? this.name,
      interests: interests ?? this.interests,
      apiKey: apiKey ?? this.apiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      learnedDates: learnedDates ?? this.learnedDates,
      streakDays: streakDays ?? this.streakDays,
      lastLearnedAt: lastLearnedAt ?? this.lastLearnedAt,
      dailyTarget: dailyTarget ?? this.dailyTarget,
    );
  }
}

enum LanguageDirection { enToJa, jaToEn }
enum RangeType { all, weak, favorites, unlearned, mastered, customRange }
enum OrderType { random, idOrder, alphabetical }

class LearningConfig {
  final LanguageDirection direction;
  final RangeType rangeType;
  final OrderType orderType;
  final int startId;
  final int endId;
  final int questionCount; // For tests

  LearningConfig({
    this.direction = LanguageDirection.enToJa,
    this.rangeType = RangeType.all,
    this.orderType = OrderType.random,
    this.startId = 1,
    this.endId = 100,
    this.questionCount = 10,
  });

  LearningConfig copyWith({
    LanguageDirection? direction,
    RangeType? rangeType,
    OrderType? orderType,
    int? startId,
    int? endId,
    int? questionCount,
  }) {
    return LearningConfig(
      direction: direction ?? this.direction,
      rangeType: rangeType ?? this.rangeType,
      orderType: orderType ?? this.orderType,
      startId: startId ?? this.startId,
      endId: endId ?? this.endId,
      questionCount: questionCount ?? this.questionCount,
    );
  }
}
