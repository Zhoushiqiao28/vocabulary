import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class CardLearningScreen extends ConsumerStatefulWidget {
  final LearningConfig config;
  const CardLearningScreen({super.key, required this.config});

  @override
  ConsumerState<CardLearningScreen> createState() => _CardLearningScreenState();
}

class _CardLearningScreenState extends ConsumerState<CardLearningScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  List<Word> _learningWords = [];
  bool _isLoading = true;
  bool _isAILoading = false;

  // 3-Phase state: 'recall', 'verify', 'challenge'
  String _phase = 'recall';

  // Challenge (mini-quiz) state
  bool _showChallenge = false;
  Word? _challengeWord;
  List<String> _challengeOptions = [];
  String? _challengeSelected;
  bool _challengeAnswered = false;
  int _cardsSinceLastChallenge = 0;
  static const int _challengeInterval = 4; // Every 4 cards

  // Session stats
  int _sessionMastered = 0;
  int _sessionWeak = 0;

  final FlutterTts _flutterTts = FlutterTts();
  final FocusNode _keyboardFocusNode = FocusNode();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initWords();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

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
    _flutterTts.stop();
    _keyboardFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initWords() async {
    final words = ref.read(wordListProvider);
    List<Word> filtered = [];

    switch (widget.config.rangeType) {
      case RangeType.all:
        filtered = List<Word>.from(words);
        break;
      case RangeType.weak:
        filtered = words.where((e) => e.status == 2).toList();
        break;
      case RangeType.favorites:
        filtered = words.where((e) => e.isFavorite).toList();
        break;
      case RangeType.unlearned:
        filtered = words.where((e) => e.status == 0).toList();
        break;
      case RangeType.mastered:
        filtered = words.where((e) => e.status == 1).toList();
        break;
      case RangeType.due:
        final now = DateTime.now();
        filtered = words.where((e) {
          return e.nextReviewAt == null || e.nextReviewAt!.isBefore(now);
        }).toList();
        break;
      case RangeType.customRange:
        filtered = words
            .where((e) => e.id >= widget.config.startId && e.id <= widget.config.endId)
            .toList();
        break;
    }

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
    _learningWords = filtered.take(limit).toList();

    setState(() {
      _isLoading = false;
    });

    if (_learningWords.isNotEmpty) {
      _prefetchWordData(0);
    }
  }

  Future<void> _prefetchWordData(int index) async {
    if (index >= _learningWords.length) return;

    final currentWord = _learningWords[index];
    if (currentWord.customExampleEn == null) {
      _fetchExampleForWord(index);
    }
    if (currentWord.coreNuance == null || currentWord.coreNuance!.isEmpty) {
      _fetchNuanceForWord(index);
    }

    final nextIndex = index + 1;
    if (nextIndex < _learningWords.length) {
      final nextWord = _learningWords[nextIndex];
      if (nextWord.customExampleEn == null) {
        _fetchExampleForWord(nextIndex);
      }
      if (nextWord.coreNuance == null || nextWord.coreNuance!.isEmpty) {
        _fetchNuanceForWord(nextIndex);
      }
    }
  }

  Future<void> _fetchNuanceForWord(int index) async {
    if (index >= _learningWords.length) return;
    final word = _learningWords[index];
    final gemini = ref.read(geminiServiceProvider);

    try {
      final explanation = await gemini.getWordNuance(word.spelling, word.meaningJa);
      if (mounted) {
        setState(() {
          _learningWords[index] = word.copyWith(coreNuance: explanation);
        });
        ref.read(wordListProvider.notifier).updateWordDetails(
              word.id,
              coreNuance: explanation,
            );
      }
    } catch (e) {
      debugPrint('Failed to prefetch nuance: $e');
    }
  }

  Future<void> _fetchExampleForWord(int index) async {
    if (index >= _learningWords.length) return;
    final word = _learningWords[index];
    final profile = ref.read(userProfileProvider);
    final gemini = ref.read(geminiServiceProvider);

    try {
      final result = await gemini.generateCustomExample(
        word.spelling,
        word.meaningJa,
        profile.interests,
      );

      if (mounted) {
        setState(() {
          _learningWords[index] = word.copyWith(
            customExampleEn: result['sentence_en'],
            customExampleJa: result['sentence_ja'],
          );
        });
        ref.read(wordListProvider.notifier).updateWordDetails(
              word.id,
              customExampleEn: result['sentence_en'],
              customExampleJa: result['sentence_ja'],
            );
      }
    } catch (e) {
      debugPrint('Failed to prefetch example: $e');
    }
  }

  // Phase 1 → Phase 2: User tapped "I recalled"
  void _revealAnswer() {
    setState(() {
      _phase = 'verify';
    });
    if (widget.config.direction == LanguageDirection.enToJa) {
      _speak(_learningWords[_currentIndex].spelling);
    }
  }

  // Phase 2 → Next card or Challenge
  Future<void> _submitAnswer(int status) async {
    final word = _learningWords[_currentIndex];
    await ref.read(wordListProvider.notifier).updateWordStatus(word.id, status);

    if (status == 1) {
      _sessionMastered++;
    } else {
      _sessionWeak++;
    }
    _cardsSinceLastChallenge++;

    if (mounted) {
      setState(() {
        _currentIndex++;
        _phase = 'recall';
      });

      if (_currentIndex >= _learningWords.length) {
        ref.read(userProfileProvider.notifier).recordLearningActivity();
      } else {
        // Check if we should insert a challenge
        if (_cardsSinceLastChallenge >= _challengeInterval && _currentIndex >= 2) {
          _triggerChallenge();
        } else {
          _animateNextCard();
          _prefetchWordData(_currentIndex);
        }
      }
    }
  }

  void _triggerChallenge() {
    // Pick a random word from the ones we've already reviewed
    final reviewedRange = _learningWords.sublist(0, _currentIndex);
    final random = Random();
    _challengeWord = reviewedRange[random.nextInt(reviewedRange.length)];

    // Generate 4 options
    final allWords = ref.read(wordListProvider);
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final correctAnswer = isEnToJa ? _challengeWord!.meaningJa : _challengeWord!.spelling;

    final options = <String>{correctAnswer};
    while (options.length < 4 && options.length < allWords.length) {
      final randomWord = allWords[random.nextInt(allWords.length)];
      final option = isEnToJa ? randomWord.meaningJa : randomWord.spelling;
      options.add(option);
    }

    final optionsList = options.toList()..shuffle();

    setState(() {
      _showChallenge = true;
      _challengeOptions = optionsList;
      _challengeSelected = null;
      _challengeAnswered = false;
      _cardsSinceLastChallenge = 0;
    });
  }

  void _answerChallenge(String option) {
    if (_challengeAnswered) return;
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final correct = isEnToJa ? _challengeWord!.meaningJa : _challengeWord!.spelling;

    setState(() {
      _challengeSelected = option;
      _challengeAnswered = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showChallenge = false;
        });
        _animateNextCard();
        _prefetchWordData(_currentIndex);
      }
    });
  }

  void _animateNextCard() {
    _fadeController.reset();
    _fadeController.forward();
  }

  Future<void> _askAIAboutWord() async {
    final word = _learningWords[_currentIndex];
    String explanation = word.coreNuance ?? '';

    if (explanation.isNotEmpty) {
      _showAIExplanationSheet(word.spelling, explanation);
      return;
    }

    setState(() => _isAILoading = true);

    final gemini = ref.read(geminiServiceProvider);

    try {
      explanation = await gemini.getWordNuance(word.spelling, word.meaningJa);
      ref.read(wordListProvider.notifier).updateWordDetails(word.id, coreNuance: explanation);
      if (mounted) {
        setState(() {
          _learningWords[_currentIndex] = word.copyWith(coreNuance: explanation);
        });
      }
    } catch (e) {
      explanation = "AI insights could not be loaded. Please try again.";
    }

    setState(() => _isAILoading = false);

    if (mounted) {
      _showAIExplanationSheet(word.spelling, explanation);
    }
  }

  void _showAIExplanationSheet(String spelling, String explanation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: AppTheme.elevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
            border: const Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sp20),
              Text(
                'AI Insight',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: AppTheme.sp8),
              Text(
                spelling,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppTheme.sp16),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    explanation,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sp16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                  child: Text(
                    '閉じる',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Compute the next interval for display
  String _nextReviewLabel(int status, Word word) {
    if (status == 2) return '明日';
    // SM-2 approximation for display
    final newInterval = word.repetitions == 0
        ? 1
        : word.repetitions == 1
            ? 4
            : (word.intervalDays * word.easeFactor).round();
    if (newInterval <= 1) return '明日';
    if (newInterval <= 7) return '$newInterval日後';
    if (newInterval <= 30) return '${(newInterval / 7).round()}週間後';
    return '${(newInterval / 30).round()}ヶ月後';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: SpinKitDoubleBounce(color: AppTheme.primary, size: 40),
        ),
      );
    }

    if (_learningWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sp32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.success.withOpacity(0.7)),
                const SizedBox(height: AppTheme.sp16),
                Text(
                  '対象の単語がありません',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: AppTheme.sp24),
                _buildActionButton('戻る', () => Navigator.pop(context), isPrimary: false),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentIndex >= _learningWords.length) {
      return _buildFinishedScreen();
    }

    // Show challenge quiz overlay
    if (_showChallenge) {
      return _buildChallengeScreen();
    }

    final currentWord = _learningWords[_currentIndex];

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            if (_phase == 'recall') {
              _revealAnswer();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
            if (_phase == 'verify') {
              _submitAnswer(2); // Weak
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
            if (_phase == 'verify') {
              _submitAnswer(1); // Mastered
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
            _askAIAboutWord();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),
              // Progress
              _buildProgressBar(),
              // Main content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
                    child: _phase == 'recall'
                        ? _buildRecallPhase(currentWord)
                        : _buildVerifyPhase(currentWord),
                  ),
                ),
              ),
              // Bottom actions
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.sp24, 0, AppTheme.sp24, AppTheme.sp24),
                child: _buildBottomActions(currentWord),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            '${_currentIndex + 1} / ${_learningWords.length}',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: _isAILoading
                ? const SizedBox(width: 20, height: 20, child: SpinKitDoubleBounce(color: AppTheme.primary, size: 18))
                : const Icon(Icons.auto_awesome_rounded, size: 20, color: AppTheme.textSecondary),
            onPressed: _askAIAboutWord,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _learningWords.isEmpty ? 0.0 : _currentIndex / _learningWords.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: AppTheme.surface,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      ),
    );
  }

  // ─── Phase 1: Recall ───
  Widget _buildRecallPhase(Word word) {
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final displayText = isEnToJa ? word.spelling : word.meaningJa;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Word display
          Text(
            displayText,
            style: GoogleFonts.outfit(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          ),
          if (isEnToJa) ...[
            const SizedBox(height: AppTheme.sp16),
            // TTS button
            GestureDetector(
              onTap: () => _speak(word.spelling),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '発音を聴く',
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.sp48),
          Text(
            '意味を思い浮かべてください',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase 2: Verify & Contextualize ───
  Widget _buildVerifyPhase(Word word) {
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppTheme.sp32),
          // Word (smaller)
          Text(
            word.spelling,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          // Meaning (large)
          Text(
            word.meaningJa,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.sp12),
          // TTS
          GestureDetector(
            onTap: () => _speak(word.spelling),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up_rounded, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text('発音', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.sp24),

          // Divider
          Container(
            height: 1,
            color: AppTheme.borderColor,
          ),
          const SizedBox(height: AppTheme.sp20),

          // Core nuance
          if (word.coreNuance != null && word.coreNuance!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.sp16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.primary.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.primary.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'コアニュアンス',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.coreNuance!,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
          ],

          // Example sentence
          if (word.customExampleEn != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.sp16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '例文',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.customExampleEn!,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (word.customExampleJa != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      word.customExampleJa!,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppTheme.sp32),
        ],
      ),
    );
  }

  // ─── Bottom Action Buttons ───
  Widget _buildBottomActions(Word word) {
    if (_phase == 'recall') {
      return _buildActionButton(
        '答えを確認する  [Space]',
        _revealAnswer,
        isPrimary: true,
      );
    }

    // Verify phase: show Weak / Mastered with next review timing
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildGradeButton(
                label: 'もう一度',
                sublabel: '→ ${_nextReviewLabel(2, word)}',
                shortcut: '1',
                color: AppTheme.error,
                onTap: () => _submitAnswer(2),
              ),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: _buildGradeButton(
                label: '覚えた！',
                sublabel: '→ ${_nextReviewLabel(1, word)}',
                shortcut: '2',
                color: AppTheme.success,
                onTap: () => _submitAnswer(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        // Keyboard shortcuts hint
        Text(
          'Space: 確認  •  1: もう一度  •  2: 覚えた  •  3: AI解説',
          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGradeButton({
    required String label,
    required String sublabel,
    required String shortcut,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 64,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$label  [$shortcut]',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: color.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback onTap, {bool isPrimary = true}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.primary : AppTheme.surface,
          foregroundColor: isPrimary ? Colors.white : AppTheme.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: isPrimary ? BorderSide.none : const BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── Phase 3: Challenge (Mini Quiz) ───
  Widget _buildChallengeScreen() {
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;
    final questionText = isEnToJa ? _challengeWord!.spelling : _challengeWord!.meaningJa;
    final correctAnswer = isEnToJa ? _challengeWord!.meaningJa : _challengeWord!.spelling;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // Challenge badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: AppTheme.warning),
                    const SizedBox(width: 4),
                    Text(
                      'Quick Check',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.sp24),
              // Question
              Text(
                isEnToJa ? '「$questionText」の意味は？' : '「$questionText」の英単語は？',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.sp32),
              // Options
              ...List.generate(_challengeOptions.length, (i) {
                final option = _challengeOptions[i];
                final isCorrect = option == correctAnswer;
                final isSelected = option == _challengeSelected;

                Color bgColor = AppTheme.surface;
                Color borderCol = AppTheme.borderColor;
                Color textCol = AppTheme.textPrimary;

                if (_challengeAnswered) {
                  if (isCorrect) {
                    bgColor = AppTheme.success.withOpacity(0.1);
                    borderCol = AppTheme.success.withOpacity(0.4);
                    textCol = AppTheme.success;
                  } else if (isSelected && !isCorrect) {
                    bgColor = AppTheme.error.withOpacity(0.1);
                    borderCol = AppTheme.error.withOpacity(0.4);
                    textCol = AppTheme.error;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.sp8),
                  child: GestureDetector(
                    onTap: () => _answerChallenge(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: borderCol),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: textCol,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Finished Screen ───
  Widget _buildFinishedScreen() {
    final total = _sessionMastered + _sessionWeak;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.sp32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.success.withOpacity(0.12),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 28,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(height: AppTheme.sp24),
                Text(
                  'セッション完了',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.sp24),

                // Stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.sp20),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _buildStatRow('復習した単語', '$total語', AppTheme.textPrimary),
                      const SizedBox(height: AppTheme.sp12),
                      _buildStatRow('習得', '$_sessionMastered語', AppTheme.success),
                      const SizedBox(height: AppTheme.sp12),
                      _buildStatRow('もう一度', '$_sessionWeak語', _sessionWeak > 0 ? AppTheme.error : AppTheme.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.sp32),
                _buildActionButton('ダッシュボードに戻る', () => Navigator.pop(context), isPrimary: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }
}
