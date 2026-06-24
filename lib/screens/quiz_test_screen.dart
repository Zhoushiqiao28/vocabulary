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
  final List<Word> _wrongWords = [];

  final FocusNode _keyboardFocusNode = FocusNode();
  Timer? _transitionTimer;

  final FlutterTts _flutterTts = FlutterTts();

  // Animating states for physical keyboard buttons
  int _pressedIndexExternal = -1;

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
      _pressedIndexExternal = -1;
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
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
      } else {
        _wrongWords.add(targetWord);
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 2);
      }
    });

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

  void _flashKeyAnimation(int index) {
    setState(() => _pressedIndexExternal = index);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _pressedIndexExternal = -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: SpinKitPulse(color: AppTheme.primary, size: 40)),
      );
    }

    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('RETENTION QUIZ')),
        body: Center(
          child: Text(
            'STATUS: NO WORDS MATCHED CONFIGURATION.',
            style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary),
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
            _flashKeyAnimation(selectIndex);
            _answer(_currentOptions[selectIndex]);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'RETENTION_QUIZ // MODULE_${_currentIndex + 1}_OF_${_quizWords.length}',
            style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LED Progress bar segments
              Row(
                children: List.generate(20, (i) {
                  final progress = (_currentIndex + 1) / _quizWords.length;
                  final isLit = (i / 20.0) < progress;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.only(right: 1.0),
                      decoration: BoxDecoration(
                        color: isLit ? AppTheme.primary : AppTheme.borderColor,
                        boxShadow: isLit
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.5),
                                  blurRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
              const Spacer(),

              // VFD Glass window question display
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  height: 180,
                  decoration: AppTheme.displayDecoration(glow: true),
                  padding: const EdgeInsets.all(24.0),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        questionText.toUpperCase(),
                        style: GoogleFonts.shareTechMono(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isEnToJa) ...[
                        const SizedBox(height: 16),
                        TactileButton(
                          width: 120,
                          height: 28,
                          onPressed: () => _speak(targetWord.spelling),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.volume_up_rounded, size: 12, color: AppTheme.textPrimary),
                              const SizedBox(width: 4),
                              Text(
                                'PLAY AUDIO',
                                style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textPrimary),
                              )
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Answer choices tactile keys panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: _currentOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedOption == option;
                    final correctValue = isEnToJa ? targetWord.meaningJa : targetWord.spelling;
                    final isCorrectOption = option == correctValue;

                    final List<String> labels = ['1 / A', '2 / B', '3 / C', '4 / D'];
                    
                    Color ledColor = AppTheme.primary;
                    bool isLedOn = false;
                    Color btnTextColor = AppTheme.textPrimary;

                    if (_hasAnswered) {
                      if (isCorrectOption) {
                        ledColor = AppTheme.success;
                        isLedOn = true;
                        btnTextColor = AppTheme.success;
                      } else if (isSelected) {
                        ledColor = AppTheme.error;
                        isLedOn = true;
                        btnTextColor = AppTheme.error;
                      } else {
                        btnTextColor = AppTheme.textSecondary;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: TactileButton(
                        height: 52,
                        onPressed: () => _answer(option),
                        isPressedExternal: _pressedIndexExternal == index,
                        ledColor: ledColor,
                        isLedOn: isLedOn,
                        color: isSelected ? AppTheme.hover : AppTheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              Text(
                                '[ ${labels[index]} ]',
                                style: GoogleFonts.shareTechMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option.toUpperCase(),
                                  style: GoogleFonts.shareTechMono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: btnTextColor,
                                  ),
                                ),
                              ),
                              if (_hasAnswered && isCorrectOption)
                                const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 14)
                              else if (_hasAnswered && isSelected)
                                const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 14)
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SHORTCUTS: PRESS KEYS [1] [2] [3] [4] OR [A] [B] [C] [D] ON PHYSICAL KEYBOARD',
                style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
                'ASSESSMENT QUANTUM STATUS',
                style: GoogleFonts.shareTechMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'SCORE: ${_score.toString().padLeft(2, '0')} / ${_quizWords.length.toString().padLeft(2, '0')}',
                style: GoogleFonts.shareTechMono(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              if (!allCorrect) ...[
                Text(
                  '// WEAK CHANNELS DETECTED:',
                  style: GoogleFonts.shareTechMono(
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
                    decoration: AppTheme.displayDecoration(glow: false),
                    child: ListView.builder(
                      itemCount: _wrongWords.length,
                      itemBuilder: (context, index) {
                        final word = _wrongWords[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                word.spelling.toUpperCase(),
                                style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              Text(
                                word.meaningJa,
                                style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.textSecondary),
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
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.success,
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'CALIBRATION PERFECT // ZERO_ERRORS',
                        style: GoogleFonts.shareTechMono(
                          color: AppTheme.success,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
              const Spacer(),
              TactileButton(
                height: 46,
                onPressed: () => Navigator.pop(context),
                color: AppTheme.primary,
                child: Text(
                  'DISMISS',
                  style: GoogleFonts.shareTechMono(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.displayBg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
