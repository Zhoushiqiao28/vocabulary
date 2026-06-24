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
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (allWords.length < 4) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('択一クイズ', style: GoogleFonts.outfit()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'クイズを開始するには、少なくとも4つ以上の単語が登録されている必要があります。',
              style: GoogleFonts.outfit(color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('択一クイズ', style: GoogleFonts.outfit()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '出題条件に該当する単語が見つかりませんでした。\n範囲設定を見直してください。',
              style: GoogleFonts.outfit(color: AppTheme.textPrimary),
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
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Q${_currentIndex + 1} / ${_quizWords.length}',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _quizWords.length,
                backgroundColor: Colors.white.withOpacity(AppTheme.borderSubtleOpacity),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 2,
                borderRadius: BorderRadius.zero,
              ),
              const SizedBox(height: 48),

              Expanded(
                flex: 2,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        questionText,
                        style: GoogleFonts.outfit(
                          fontSize: isEnToJa ? 48 : 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isEnToJa) ...[
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.volume_up_rounded, size: 36, color: AppTheme.info),
                          onPressed: () => _speak(targetWord.spelling),
                          tooltip: '発音を聞く',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                flex: 4,
                child: Column(
                  children: _currentOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedOption == option;
                    final isCorrectOption = option == (isEnToJa ? targetWord.meaningJa : targetWord.spelling);

                    Color bgColor = Colors.transparent;
                    Color textColor = AppTheme.textPrimary;

                    if (_hasAnswered) {
                      if (isCorrectOption) {
                        bgColor = AppTheme.success;
                        textColor = const Color(0xFF0A0A0A);
                      } else if (isSelected) {
                        bgColor = AppTheme.error;
                        textColor = const Color(0xFF0A0A0A);
                      } else {
                        textColor = AppTheme.textSecondary;
                      }
                    }

                    return Expanded(
                      child: InkWell(
                        onTap: () => _answer(option),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            border: Border(
                              top: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity), width: 1),
                              bottom: index == _currentOptions.length - 1 
                                  ? BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity), width: 1)
                                  : BorderSide.none,
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            option,
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (_hasAnswered)
                InkWell(
                  onTap: _nextQuestion,
                  child: Container(
                    height: 80,
                    color: AppTheme.primary,
                    alignment: Alignment.center,
                    child: Text(
                      _currentIndex + 1 == _quizWords.length ? 'FINISH' : 'NEXT',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final allCorrect = _wrongWords.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'SCORE',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '$_score',
                style: GoogleFonts.outfit(
                  fontSize: 120,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              'OUT OF ${_quizWords.length}',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            if (!allCorrect) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'REVIEW',
                  style: GoogleFonts.outfit(
                    color: AppTheme.error,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _wrongWords.length,
                  itemBuilder: (context, index) {
                    final word = _wrongWords[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity), width: 1),
                          bottom: index == _wrongWords.length - 1 
                              ? BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity), width: 1)
                              : BorderSide.none,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              word.spelling,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              word.meaningJa,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppTheme.success, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        'PERFECT',
                        style: GoogleFonts.outfit(
                          color: AppTheme.success,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
            
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 80,
                color: AppTheme.primary,
                alignment: Alignment.center,
                child: Text(
                  'CLOSE',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
