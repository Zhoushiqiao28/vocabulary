import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class CardLearningScreen extends ConsumerStatefulWidget {
  final LearningConfig config;
  const CardLearningScreen({super.key, required this.config});

  @override
  ConsumerState<CardLearningScreen> createState() => _CardLearningScreenState();
}

class _CardLearningScreenState extends ConsumerState<CardLearningScreen> {
  int _currentIndex = 0;
  List<Word> _learningWords = [];
  bool _isLoading = true;
  bool _showFront = true;
  bool _isAILoading = false;

  // External physical keyboard animation states
  bool _isSpacePressed = false;
  bool _is1Pressed = false;
  bool _is2Pressed = false;
  bool _is3Pressed = false;

  final FlutterTts _flutterTts = FlutterTts();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initTts();
    _initWords();
    
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
    super.dispose();
  }

  Future<void> _initWords() async {
    final words = ref.read(wordListProvider);
    List<Word> filtered = [];

    // Apply Range Filter
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

    // Apply Limit
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

    // Prefetch next word
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

  void _flipCard() {
    setState(() {
      _showFront = !_showFront;
    });
    // Auto-TTS spelling on flip to back
    if (!_showFront && widget.config.direction == LanguageDirection.enToJa) {
      _speak(_learningWords[_currentIndex].spelling);
    }
  }

  Future<void> _submitAnswer(int status) async {
    final word = _learningWords[_currentIndex];
    await ref.read(wordListProvider.notifier).updateWordStatus(word.id, status);

    if (mounted) {
      setState(() {
        _currentIndex++;
        _showFront = true;
      });

      if (_currentIndex >= _learningWords.length) {
        ref.read(userProfileProvider.notifier).recordLearningActivity();
      } else {
        _prefetchWordData(_currentIndex);
      }
    }
  }

  Future<void> _askAIAboutWord() async {
    final word = _learningWords[_currentIndex];
    String explanation = word.coreNuance ?? '';

    if (explanation.isNotEmpty) {
      _showAIExplanationBottomSheet(word.spelling, explanation);
      return;
    }

    setState(() {
      _isAILoading = true;
    });

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
      explanation = "Failed to fetch AI insights. Please try again later.";
    }

    setState(() {
      _isAILoading = false;
    });

    if (mounted) {
      _showAIExplanationBottomSheet(word.spelling, explanation);
    }
  }

  void _showAIExplanationBottomSheet(String spelling, String explanation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI_INSIGHT // SPECTRUM_ANALYZE',
                style: GoogleFonts.shareTechMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                spelling.toUpperCase(),
                style: GoogleFonts.shareTechMono(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    explanation,
                    style: GoogleFonts.shareTechMono(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TactileButton(
                height: 44,
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'DISMISS',
                  style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // Helper to flash tactile animation on keyboard press
  void _flashKeyAnimation(String key) {
    if (key == 'space') {
      setState(() => _isSpacePressed = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isSpacePressed = false);
      });
    } else if (key == '1') {
      setState(() => _is1Pressed = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _is1Pressed = false);
      });
    } else if (key == '2') {
      setState(() => _is2Pressed = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _is2Pressed = false);
      });
    } else if (key == '3') {
      setState(() => _is3Pressed = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _is3Pressed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: SpinKitPulse(color: AppTheme.primary, size: 40),
        ),
      );
    }

    if (_currentIndex >= _learningWords.length) {
      return _buildFinishedScreen();
    }

    final currentWord = _learningWords[_currentIndex];

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _flashKeyAnimation('space');
            _flipCard();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
            if (!_showFront) {
              _flashKeyAnimation('1');
              _submitAnswer(2); // Weak
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
            if (!_showFront) {
              _flashKeyAnimation('2');
              _submitAnswer(1); // Mastered
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
            _flashKeyAnimation('3');
            _askAIAboutWord();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          title: Text(
            'CHASSIS_SLOT: ${_currentIndex + 1} / ${_learningWords.length}',
            style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 16),
              onPressed: _askAIAboutWord,
            )
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // VFD Monitor glass window
                Expanded(
                  child: Container(
                    decoration: AppTheme.displayDecoration(glow: true),
                    padding: const EdgeInsets.all(24.0),
                    alignment: Alignment.center,
                    child: _isAILoading
                        ? const SpinKitThreeBounce(color: AppTheme.primary, size: 24)
                        : _buildWorkspaceContent(currentWord),
                  ),
                ),
                const SizedBox(height: 24),

                // Physical tactile buttons row
                Column(
                  children: [
                    if (_showFront) ...[
                      TactileButton(
                        height: 48,
                        onPressed: _flipCard,
                        isPressedExternal: _isSpacePressed,
                        color: AppTheme.primary,
                        ledColor: Colors.white,
                        isLedOn: true,
                        child: Text(
                          'READ OUT DATA [Space]',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.displayBg,
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TactileButton(
                              height: 48,
                              onPressed: () => _submitAnswer(2),
                              isPressedExternal: _is1Pressed,
                              color: AppTheme.surface,
                              ledColor: AppTheme.error,
                              isLedOn: true,
                              child: Text(
                                'WEAK [1]',
                                style: GoogleFonts.shareTechMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.error,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TactileButton(
                              height: 48,
                              onPressed: () => _submitAnswer(1),
                              isPressedExternal: _is2Pressed,
                              color: AppTheme.primary,
                              ledColor: AppTheme.success,
                              isLedOn: true,
                              child: Text(
                                'MASTERED [2]',
                                style: GoogleFonts.shareTechMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.displayBg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    
                    // Extra option button: AI Insight (mapped to key 3)
                    TactileButton(
                      height: 38,
                      onPressed: _askAIAboutWord,
                      isPressedExternal: _is3Pressed,
                      color: AppTheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 12, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'AI NUANCE SPECTRUM [3]',
                            style: GoogleFonts.shareTechMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SHORTCUTS: [SPACE] FLIP  •  [1] WEAK  •  [2] MASTERED  •  [3] AI INSIGHT',
                      style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Work space core rendering
  Widget _buildWorkspaceContent(Word word) {
    final isEnToJa = widget.config.direction == LanguageDirection.enToJa;

    if (_showFront) {
      // FRONT SIDE
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEnToJa ? word.spelling.toUpperCase() : word.meaningJa,
            style: GoogleFonts.shareTechMono(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isEnToJa)
            TactileButton(
              width: 130,
              height: 32,
              onPressed: () => _speak(word.spelling),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volume_up_rounded, size: 12, color: AppTheme.textPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'PLAY AUDIO',
                    style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textPrimary),
                  )
                ],
              ),
            ),
        ],
      );
    } else {
      // BACK SIDE
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    word.spelling.toUpperCase(),
                    style: GoogleFonts.shareTechMono(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    word.meaningJa,
                    style: GoogleFonts.shareTechMono(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TactileButton(
                    width: 120,
                    height: 28,
                    onPressed: () => _speak(word.spelling),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up_rounded, size: 10, color: AppTheme.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'PLAY AUDIO',
                          style: GoogleFonts.shareTechMono(fontSize: 9, color: AppTheme.textPrimary),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),

            // Contextual examples (Dynamic/AI generated)
            if (word.customExampleEn != null || word.coreNuance != null) ...[
              if (word.coreNuance != null && word.coreNuance!.isNotEmpty) ...[
                Text(
                  '// NUANCE:',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.coreNuance!,
                  style: GoogleFonts.shareTechMono(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 16),
              ],
              if (word.customExampleEn != null) ...[
                Text(
                  '// LIVE EXAMPLE:',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.customExampleEn!,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.customExampleJa!,
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ]
            ],
          ],
        ),
      );
    }
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            decoration: AppTheme.displayDecoration(glow: true),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
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
                  'CALIBRATION COMPLETE',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SPACED REPETITION QUANTUM STATES SYNCHRONIZED.',
                  style: GoogleFonts.shareTechMono(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TactileButton(
                  width: 140,
                  height: 40,
                  onPressed: () => Navigator.pop(context),
                  color: AppTheme.primary,
                  child: Text(
                    'DISMISS',
                    style: GoogleFonts.shareTechMono(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.displayBg,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
