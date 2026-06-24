import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
      case RangeType.due:
        final now = DateTime.now();
        filtered = allWords.where((e) {
          return e.nextReviewAt == null || e.nextReviewAt!.isBefore(now);
        }).toList();
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

    if (isEnToJa) {
      _speak(targetWord.spelling);
    }
  }

  void _answer(String option) {
    if (_hasAnswered) return;

    final targetWord = _quizWords[_currentIndex];
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final correctValue = isEnToJa ? targetWord.meaningJa : targetWord.spelling;
    final isCorrect = option == correctValue;

    setState(() {
      _selectedOption = option;
      _hasAnswered = true;
      if (isCorrect) {
        _score++;
        // Update SRS status under SM-2 (1: Mastered)
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
      } else {
        _wrongWords.add(targetWord);
        // Update SRS status under SM-2 (2: Weak)
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 2);
      }
    });

    // Auto navigate after 1.5s
    _transitionTimer = Timer(const Duration(milliseconds: 1500), () {
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
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: SpinKitPulse(color: AppTheme.textSecondary, size: 40)),
      );
    }

    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Quiz Test')),
        body: const Center(
          child: Text('No words match your selected configuration.'),
        ),
      );
    }

    if (_currentIndex >= _quizWords.length) {
      return _buildFinishedScreen();
    }

    final targetWord = _quizWords[_currentIndex];
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final questionText = isEnToJa ? targetWord.spelling : targetWord.meaningJa;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !_hasAnswered) {
          int? selectIndex;
          if (event.logicalKey == LogicalKeyboardKey.keyA || event.logicalKey == LogicalKeyboardKey.digit1) {
            selectIndex = 0;
          } else if (event.logicalKey == LogicalKeyboardKey.keyB || event.logicalKey == LogicalKeyboardKey.digit2) {
            selectIndex = 1;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC || event.logicalKey == LogicalKeyboardKey.digit3) {
            selectIndex = 2;
          } else if (event.logicalKey == LogicalKeyboardKey.keyD || event.logicalKey == LogicalKeyboardKey.digit4) {
            selectIndex = 3;
          }

          if (selectIndex != null && selectIndex < _currentOptions.length) {
            _answer(_currentOptions[selectIndex]);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('QUIZ ASSESSMENT (${_currentIndex + 1}/${_quizWords.length})'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _quizWords.length,
                backgroundColor: AppTheme.borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 2,
              ),
              const Spacer(),

              // Question display
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      questionText,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isEnToJa) ...[
                      const SizedBox(height: 12),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 24, color: AppTheme.textSecondary),
                        onPressed: () => _speak(targetWord.spelling),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),

              // Answer choices list table
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Container(
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: _currentOptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final isSelected = _selectedOption == option;
                      final isCorrectOption = option == (isEnToJa ? targetWord.meaningJa : targetWord.spelling);

                      final List<String> labels = ['A', 'B', 'C', 'D'];
                      
                      Color optionColor = AppTheme.textPrimary;
                      FontWeight optionWeight = FontWeight.w500;

                      if (_hasAnswered) {
                        if (isCorrectOption) {
                          optionColor = AppTheme.success;
                          optionWeight = FontWeight.bold;
                        } else if (isSelected) {
                          optionColor = AppTheme.error;
                          optionWeight = FontWeight.bold;
                        } else {
                          optionColor = AppTheme.textSecondary;
                        }
                      }

                      return InkWell(
                        onTap: () => _answer(option),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                          decoration: BoxDecoration(
                            border: index < 3
                                ? const Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5))
                                : null,
                          ),
                          child: Row(
                            children: [
                              Text(
                                labels[index],
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: optionWeight,
                                    color: optionColor,
                                  ),
                                ),
                              ),
                              if (_hasAnswered && isCorrectOption)
                                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 16)
                              else if (_hasAnswered && isSelected)
                                const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 16)
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final allCorrect = _wrongWords.isEmpty;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'ASSESSMENT COMPLETE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_score / ${_quizWords.length}',
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: -1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              if (!allCorrect) ...[
                Text(
                  'REVIEW WEAK WORDS',
                  style: GoogleFonts.inter(
                    color: AppTheme.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: AppTheme.cardDecoration(),
                    child: ListView.builder(
                      itemCount: _wrongWords.length,
                      itemBuilder: (context, index) {
                        final word = _wrongWords[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            border: index < _wrongWords.length - 1
                                ? const Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5))
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                word.spelling,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              Text(
                                word.meaningJa,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else ...[
                const Spacer(),
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'PERFECT SCORE',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('DONE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
