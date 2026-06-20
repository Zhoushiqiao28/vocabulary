import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'dart:async';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class QuizTestScreen extends ConsumerStatefulWidget {
  final LearningConfig config;
  const QuizTestScreen({super.key, required this.config});

  @override
  ConsumerState<QuizTestScreen> createState() => _QuizTestScreenState();
}

class _QuizTestScreenState extends ConsumerState<QuizTestScreen> {
  List<Word> _quizWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  List<String> _currentOptions = [];
  String? _selectedOption;
  bool _hasAnswered = false;

  int _score = 0;
  List<Word> _wrongWords = [];

  final FocusNode _keyboardFocusNode = FocusNode();
  Timer? _transitionTimer;

  // TTS
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _generateQuiz();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _transitionTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _generateQuiz() {
    final allWords = ref.read(wordListProvider);
    if (allWords.length < 4) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    List<Word> filtered = [];
    switch (widget.config.rangeType) {
      case RangeType.all:
        filtered = List<Word>.from(allWords);
        break;
      case RangeType.weak:
        filtered = allWords.where((e) => e.status == 2).toList();
        break;
      case RangeType.favorites:
        filtered = allWords.where((e) => e.isFavorite).toList();
        break;
      case RangeType.unlearned:
        filtered = allWords.where((e) => e.status == 0).toList();
        break;
      case RangeType.mastered:
        filtered = allWords.where((e) => e.status == 1).toList();
        break;
      case RangeType.customRange:
        filtered = allWords
            .where((e) => e.id >= widget.config.startId && e.id <= widget.config.endId)
            .toList();
        break;
    }

    if (filtered.isEmpty) {
      setState(() {
        _quizWords = [];
        _isLoading = false;
      });
      return;
    }

    // Apply Sorting
    switch (widget.config.orderType) {
      case OrderType.random:
        filtered.shuffle();
        break;
      case OrderType.idOrder:
        filtered.sort((a, b) => a.id.compareTo(b.id));
        break;
      case OrderType.alphabetical:
        filtered.sort((a, b) => a.spelling.toLowerCase().compareTo(b.spelling.toLowerCase()));
        break;
    }

    // Limit count
    final limit = widget.config.questionCount == 9999 ? filtered.length : widget.config.questionCount;
    _quizWords = filtered.take(limit).toList();

    setState(() {
      _isLoading = false;
    });

    if (_quizWords.isNotEmpty) {
      _loadQuestion();
    }
  }

  void _loadQuestion() {
    if (_currentIndex >= _quizWords.length) return;

    final targetWord = _quizWords[_currentIndex];
    final allWords = ref.read(wordListProvider);

    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final targetValue = isEnToJa ? targetWord.meaningJa : targetWord.spelling;
    final options = <String>{targetValue};
    final random = Random();

    while (options.length < 4) {
      final randomWord = allWords[random.nextInt(allWords.length)];
      if (randomWord.id != targetWord.id) {
        options.add(isEnToJa ? randomWord.meaningJa : randomWord.spelling);
      }
    }

    setState(() {
      _currentOptions = options.toList()..shuffle();
      _selectedOption = null;
      _hasAnswered = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });

    // Auto speak the word if direction is EN->JP
    if (isEnToJa) {
      _speak(targetWord.spelling);
    }
  }

  void _answer(String option) {
    if (_hasAnswered) return;

    final targetWord = _quizWords[_currentIndex];
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final correctAnswer = isEnToJa ? targetWord.meaningJa : targetWord.spelling;
    final isCorrect = option == correctAnswer;

    // Auto speak the word on answer (especially for JA->EN)
    _speak(targetWord.spelling);

    setState(() {
      _selectedOption = option;
      _hasAnswered = true;
      if (isCorrect) {
        _score++;
        if (targetWord.status != 1) {
          ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
        }
      } else {
        _wrongWords.add(targetWord);
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 2);
      }
    });

    if (_currentIndex + 1 >= _quizWords.length) {
      ref.read(userProfileProvider.notifier).recordLearningActivity();
    }

    _transitionTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    _transitionTimer?.cancel();
    if (_currentIndex + 1 < _quizWords.length) {
      setState(() {
        _currentIndex++;
      });
      _loadQuestion();
    } else {
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allWords = ref.watch(wordListProvider);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (allWords.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('択一クイズ')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'クイズを開始するには、少なくとも4つ以上の単語が登録されている必要があります。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_quizWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('択一クイズ')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              '出題条件に該当する単語が見つかりませんでした。\n範囲設定を見直してください。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_currentIndex >= _quizWords.length) {
      return _buildFinishedScreen();
    }

    final targetWord = _quizWords[_currentIndex];
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final questionText = isEnToJa ? targetWord.spelling : targetWord.meaningJa;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (_hasAnswered) {
            _nextQuestion();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('択一クイズ (${_currentIndex + 1}/${_quizWords.length})'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _quizWords.length,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 48),
  
                Expanded(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            questionText,
                            style: GoogleFonts.outfit(
                              fontSize: isEnToJa ? 38 : 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (isEnToJa) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded, size: 30, color: AppTheme.secondary),
                            onPressed: () => _speak(targetWord.spelling),
                            tooltip: '発音を聞く',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
  
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _currentOptions.map((option) {
                      final isSelected = _selectedOption == option;
                      final isCorrectOption = option == (isEnToJa ? targetWord.meaningJa : targetWord.spelling);
                      
                      Color cardColor = AppTheme.surface;
                      Color borderColor = Colors.white.withOpacity(0.05);
                      Color textColor = AppTheme.textPrimary;
  
                      if (_hasAnswered) {
                        if (isCorrectOption) {
                          cardColor = Colors.teal.withOpacity(0.12);
                          borderColor = Colors.teal;
                          textColor = Colors.tealAccent;
                        } else if (isSelected) {
                          cardColor = Colors.redAccent.withOpacity(0.12);
                          borderColor = Colors.redAccent;
                          textColor = Colors.redAccent;
                        }
                      }
  
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _answer(option),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
  
                if (_hasAnswered)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentIndex + 1 == _quizWords.length ? '結果を確認' : '次へ進む',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final allCorrect = _wrongWords.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // スリム化された高級感のあるヘッダー
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.1),
                        border: Border.all(color: AppTheme.primary, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'クイズ完了！ 🎉',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'スコア: $_score / ${_quizWords.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (!allCorrect) ...[
                Text(
                  '❌ 要復習単語（自動で「覚えてない」に登録されました）',
                  style: TextStyle(
                    color: Colors.redAccent[100],
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _wrongWords.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final word = _wrongWords[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              word.spelling,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              word.meaningJa,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.tealAccent, size: 64),
                        SizedBox(height: 16),
                        Text(
                          '素晴らしい！全問正解です！🌟',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '閉じる',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
