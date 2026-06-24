import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:async';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SpellingTestScreen extends ConsumerStatefulWidget {
  final LearningConfig config;
  const SpellingTestScreen({super.key, required this.config});

  @override
  ConsumerState<SpellingTestScreen> createState() => _SpellingTestScreenState();
}

class _SpellingTestScreenState extends ConsumerState<SpellingTestScreen> {
  List<Word> _testWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  Timer? _transitionTimer;

  bool _hasChecked = false;
  bool _isCorrect = false;
  bool _showHint = false;

  int _score = 0;
  final List<Word> _wrongWords = [];

  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _generateTest();
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
    _inputController.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _transitionTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _generateTest() {
    final allWords = ref.read(wordListProvider);
    if (allWords.isEmpty) {
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
        _testWords = [];
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
    _testWords = filtered.take(limit).toList();

    setState(() {
      _isLoading = false;
    });

    if (_testWords.isNotEmpty) {
      _loadQuestion();
    }
  }

  void _loadQuestion() {
    setState(() {
      _inputController.clear();
      _hasChecked = false;
      _isCorrect = false;
      _showHint = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _checkAnswer() {
    if (_hasChecked) return;

    final targetWord = _testWords[_currentIndex];
    final answer = _inputController.text.trim().toLowerCase();
    final isCorrect = answer == targetWord.spelling.toLowerCase();

    setState(() {
      _isCorrect = isCorrect;
      _hasChecked = true;
      if (isCorrect) {
        _score++;
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
      } else {
        _wrongWords.add(targetWord);
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 2);
      }
    });

    _speak(targetWord.spelling);

    _transitionTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    _transitionTimer?.cancel();
    if (_currentIndex + 1 < _testWords.length) {
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
        body: Center(child: SpinKitPulse(color: AppTheme.primary, size: 40)),
      );
    }

    if (_testWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'スペリングテスト',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            '条件に一致する単語が見つかりませんでした',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    if (_currentIndex >= _testWords.length) {
      return _buildFinishedScreen();
    }

    final targetWord = _testWords[_currentIndex];
    final hintText = targetWord.spelling.isNotEmpty
        ? '${targetWord.spelling[0]}${'_' * (targetWord.spelling.length - 1)}'
        : '';

    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _hasChecked) {
          if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space) {
            _nextQuestion();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'スペリングテスト  ${_currentIndex + 1} / ${_testWords.length}',
            style: GoogleFonts.outfit(
              fontSize: 16,
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
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _testWords.length,
                  minHeight: 3,
                  backgroundColor: AppTheme.borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),

              const Spacer(),

              // Question area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
                child: Container(
                  decoration: AppTheme.cardDecoration(radius: AppTheme.radiusLg),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.sp24,
                    vertical: AppTheme.sp32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Japanese meaning prompt
                      Text(
                        targetWord.meaningJa,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppTheme.sp20),

                      // Hint / Answer / Hint Button
                      if (_showHint || _hasChecked)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _hasChecked ? targetWord.spelling : hintText,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: _hasChecked
                                    ? (_isCorrect ? AppTheme.success : AppTheme.error)
                                    : AppTheme.info,
                              ),
                            ),
                            if (_hasChecked) ...[
                              const SizedBox(width: AppTheme.sp8),
                              IconButton(
                                icon: const Icon(
                                  Icons.volume_up_rounded,
                                  size: 20,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () => _speak(targetWord.spelling),
                              ),
                            ],
                          ],
                        )
                      else
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _showHint = true;
                            });
                            _speak(targetWord.spelling);
                          },
                          icon: const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: AppTheme.info,
                          ),
                          label: Text(
                            'ヒントを表示',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.info,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Input area
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp24,
                  vertical: AppTheme.sp16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _checkAnswer(),
                      enabled: !_hasChecked,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _hasChecked
                            ? (_isCorrect ? AppTheme.success : AppTheme.error)
                            : AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'スペルを入力...',
                        hintStyle: GoogleFonts.outfit(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppTheme.sp16,
                          horizontal: AppTheme.sp16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          borderSide: BorderSide(
                            color: _hasChecked
                                ? (_isCorrect ? AppTheme.success.withOpacity(0.4) : AppTheme.error.withOpacity(0.4))
                                : AppTheme.borderColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp16),

                    // Check / Next button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _hasChecked ? _nextQuestion : _checkAnswer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasChecked
                              ? (_isCorrect ? AppTheme.success : AppTheme.error)
                              : AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _hasChecked ? '次へ進む' : '解答する',
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
              const SizedBox(height: AppTheme.sp12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final allCorrect = _wrongWords.isEmpty;
    final percentage = (_score / _testWords.length * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Header
              Text(
                'テスト完了',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp8),

              // Score
              Text(
                '$_score / ${_testWords.length}',
                style: GoogleFonts.outfit(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  letterSpacing: -1.0,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                '$percentage% 正解',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp32),

              if (!allCorrect) ...[
                // Wrong words header
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: AppTheme.sp8),
                    Text(
                      '間違えた単語',
                      style: GoogleFonts.outfit(
                        color: AppTheme.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.sp12),

                // Wrong words list
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: AppTheme.cardDecoration(radius: AppTheme.radiusMd),
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
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.success.withOpacity(0.12),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppTheme.success,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp16),
                      Text(
                        'パーフェクト！',
                        style: GoogleFonts.outfit(
                          color: AppTheme.success,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.sp4),
                      Text(
                        'すべて正解しました',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],

              const Spacer(),

              // Dismiss button
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
