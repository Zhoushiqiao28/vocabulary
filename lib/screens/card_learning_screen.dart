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

  final FlutterTts _flutterTts = FlutterTts();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initTts();
    _initWords();
    
    // Request keyboard focus
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
            color: AppTheme.elevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI INSIGHT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                spelling.toLowerCase(),
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    explanation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: SpinKitPulse(color: AppTheme.textSecondary, size: 40),
        ),
      );
    }

    if (_currentIndex >= _learningWords.length) {
      return _buildFinishedScreen();
    }

    final currentWord = _learningWords[_currentIndex];

    // Wrap in a Focus widget to capture physical keyboard keys
    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _flipCard();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
            if (!_showFront) {
              _submitAnswer(2); // Weak
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
            if (!_showFront) {
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
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          elevation: 0,
          title: Text(
            '${_currentIndex + 1} / ${_learningWords.length}',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
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
                const Spacer(),
                
                // Studio mode central text display
                Center(
                  child: _isAILoading
                      ? const SpinKitThreeBounce(color: AppTheme.primary, size: 24)
                      : _buildWorkspaceContent(currentWord),
                ),
                
                const Spacer(),

                // Action area based on Front/Back state
                Column(
                  children: [
                    if (_showFront) ...[
                      OutlinedButton(
                        onPressed: _flipCard,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        child: const Text('SHOW ANSWER [Space]'),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _submitAnswer(2),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              child: const Text('WEAK [1]'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _submitAnswer(1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              child: const Text('MASTERED [2]'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Press [Space] to flip card  •  [1] Weak  •  [2] Mastered  •  [3] AI Insight',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
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
            isEnToJa ? word.spelling : word.meaningJa,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (isEnToJa)
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, size: 24, color: AppTheme.textSecondary),
              onPressed: () => _speak(word.spelling),
              tooltip: 'Listen pronunciation',
            ),
        ],
      );
    } else {
      // BACK SIDE
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  word.spelling,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.meaningJa,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppTheme.textSecondary),
                  onPressed: () => _speak(word.spelling),
                  tooltip: 'Listen pronunciation',
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Contextual examples (Dynamic/AI generated)
          if (word.customExampleEn != null || word.coreNuance != null)
            Container(
              padding: const EdgeInsets.only(left: 14.0, top: 4.0, bottom: 4.0),
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppTheme.primary, width: 2.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (word.coreNuance != null && word.coreNuance!.isNotEmpty) ...[
                    Text(
                      'NUANCE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.coreNuance!,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (word.customExampleEn != null) ...[
                    Text(
                      'EXAMPLE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.customExampleEn!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.customExampleJa!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ]
                ],
              ),
            ),
        ],
      );
    }
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Session Complete',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Spaced Repetition schedules updated successfully.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
