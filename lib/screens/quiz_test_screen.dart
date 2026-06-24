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
        appBar: AppBar(title: Text('選択肢クイズ', style: GoogleFonts.outfit())),
        body: Center(
          child: Text(
            '条件に一致する単語がありません',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 15),
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
    final progress = (_currentIndex + 1) / _quizWords.length;

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
            '選択肢クイズ  ${_currentIndex + 1} / ${_quizWords.length}',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clean progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
              const Spacer(),

              // Question card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 160),
                  decoration: AppTheme.cardDecoration(
                    color: AppTheme.surface,
                    radius: AppTheme.radiusMd,
                  ),
                  padding: const EdgeInsets.all(AppTheme.sp24),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        questionText,
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isEnToJa) ...[
                        const SizedBox(height: AppTheme.sp16),
                        TextButton.icon(
                          onPressed: () => _speak(targetWord.spelling),
                          icon: const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.primary),
                          label: Text(
                            '発音を聞く',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.sp16,
                              vertical: AppTheme.sp8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Answer options
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp24,
                  vertical: AppTheme.sp16,
                ),
                child: Column(
                  children: _currentOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = _selectedOption == option;
                    final correctValue = isEnToJa ? targetWord.meaningJa : targetWord.spelling;
                    final isCorrectOption = option == correctValue;

                    final List<String> labels = ['A', 'B', 'C', 'D'];
                    final isPressed = _pressedIndexExternal == index;

                    Color bgColor = AppTheme.surface;
                    Color borderCol = AppTheme.borderColor;
                    Color textColor = AppTheme.textPrimary;
                    Color labelColor = AppTheme.textMuted;
                    IconData? trailingIcon;
                    Color? trailingColor;

                    if (_hasAnswered) {
                      if (isCorrectOption) {
                        bgColor = AppTheme.success.withOpacity(0.1);
                        borderCol = AppTheme.success.withOpacity(0.4);
                        textColor = AppTheme.success;
                        labelColor = AppTheme.success;
                        trailingIcon = Icons.check_circle_rounded;
                        trailingColor = AppTheme.success;
                      } else if (isSelected) {
                        bgColor = AppTheme.error.withOpacity(0.1);
                        borderCol = AppTheme.error.withOpacity(0.4);
                        textColor = AppTheme.error;
                        labelColor = AppTheme.error;
                        trailingIcon = Icons.cancel_rounded;
                        trailingColor = AppTheme.error;
                      } else {
                        textColor = AppTheme.textMuted;
                        labelColor = AppTheme.textMuted;
                      }
                    } else if (isPressed) {
                      bgColor = AppTheme.hover;
                      borderCol = AppTheme.primary.withOpacity(0.5);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.sp8),
                      child: GestureDetector(
                        onTap: () => _answer(option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 52,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: borderCol, width: 1.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: labelColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  labels[index],
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.sp12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (trailingIcon != null)
                                Icon(trailingIcon, color: trailingColor, size: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                'キーボード 1〜4 / A〜D で回答',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final allCorrect = _wrongWords.isEmpty;
    final percentage = (_score / _quizWords.length * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'クイズ結果',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp8),
              Text(
                '$_score / ${_quizWords.length}',
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  color: allCorrect ? AppTheme.success : AppTheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                '正答率 $percentage%',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp24),

              if (!allCorrect) ...[
                Text(
                  '間違えた単語',
                  style: GoogleFonts.outfit(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.sp8),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: AppTheme.cardDecoration(
                      color: AppTheme.surface,
                      radius: AppTheme.radiusMd,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _wrongWords.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppTheme.borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final word = _wrongWords[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.sp12,
                            horizontal: AppTheme.sp16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                word.spelling,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                word.meaningJa,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
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
                      Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: AppTheme.success,
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      Text(
                        'すべて正解！',
                        style: GoogleFonts.outfit(
                          color: AppTheme.success,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '閉じる',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
