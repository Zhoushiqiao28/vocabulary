import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class CardLearningScreen extends ConsumerStatefulWidget {
  final LearningConfig config;
  const CardLearningScreen({super.key, required this.config});

  @override
  ConsumerState<CardLearningScreen> createState() => _CardLearningScreenState();
}

class _CardLearningScreenState extends ConsumerState<CardLearningScreen> with TickerProviderStateMixin {
  // Navigation & Word States
  int _currentIndex = 0;
  List<Word> _learningWords = [];
  bool _isLoading = true;

  // Animation & Swipe Controllers
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  double _swipeAngle = 0.0;

  // 3D Flip Card Controllers
  bool _showFront = true;
  late AnimationController _flipController;

  // Background Highlight Animation Progress
  double _swipeProgressRight = 0.0;
  double _swipeProgressLeft = 0.0;
  double _swipeProgressUp = 0.0;

  // AI Loadings
  bool _isAILoading = false;

  // TTS
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeOut));

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _initWords();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
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
    
    // 現在の単語の例文・解説をフェッチ
    final currentWord = _learningWords[index];
    if (currentWord.customExampleEn == null) {
      _fetchExampleForWord(index);
    }
    if (currentWord.coreNuance == null || currentWord.coreNuance!.isEmpty) {
      _fetchNuanceForWord(index);
    }

    // 次の単語
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

    // その次の単語（1秒遅れてフェッチ）
    final nextNextIndex = index + 2;
    if (nextNextIndex < _learningWords.length) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _currentIndex == index) {
          final nextNextWord = _learningWords[nextNextIndex];
          if (nextNextWord.customExampleEn == null) {
            _fetchExampleForWord(nextNextIndex);
          }
          if (nextNextWord.coreNuance == null || nextNextWord.coreNuance!.isEmpty) {
            _fetchNuanceForWord(nextNextIndex);
          }
        }
      });
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
      debugPrint('Failed to prefetch nuance for ${word.spelling}: $e');
    }
  }

  Future<void> _fetchExampleForWord(int index) async {
    final word = _learningWords[index];
    final profile = ref.read(userProfileProvider);
    final gemini = ref.read(geminiServiceProvider);
    
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
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _swipeController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_showFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _swipeAngle = (_dragOffset.dx / 300.0) * 0.15;

      _swipeProgressRight = max(0.0, min(1.0, _dragOffset.dx / 150.0));
      _swipeProgressLeft = max(0.0, min(1.0, -_dragOffset.dx / 150.0));
      _swipeProgressUp = max(0.0, min(1.0, -_dragOffset.dy / 150.0));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    const double threshold = 120.0;
    
    if (_dragOffset.dx > threshold) {
      _triggerSwipe(const Offset(500, 0), 1);
    } else if (_dragOffset.dx < -threshold) {
      _triggerSwipe(const Offset(-500, 0), 2);
    } else if (_dragOffset.dy < -threshold) {
      _askAIAboutWord();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _swipeAngle = 0.0;
        _swipeProgressRight = 0.0;
        _swipeProgressLeft = 0.0;
        _swipeProgressUp = 0.0;
      });
    }
  }

  Future<void> _triggerSwipe(Offset target, int status) async {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(parent: _swipeController, curve: Curves.easeInOut));

    await _swipeController.forward();
    
    final word = _learningWords[_currentIndex];
    await ref.read(wordListProvider.notifier).updateWordStatus(word.id, status);

    if (mounted) {
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _swipeAngle = 0.0;
        _swipeProgressRight = 0.0;
        _swipeProgressLeft = 0.0;
        _swipeProgressUp = 0.0;
        _showFront = true;
      });

      if (_currentIndex >= _learningWords.length) {
        ref.read(userProfileProvider.notifier).recordLearningActivity();
      }

      _swipeController.reset();
      _flipController.reset();

      _prefetchWordData(_currentIndex);
    }
  }

  Future<void> _askAIAboutWord() async {
    final word = _learningWords[_currentIndex];
    String explanation = word.coreNuance ?? '';

    // すでにキャッシュがある場合は、ローディングを挟まずに即座に表示
    if (explanation.isNotEmpty) {
      setState(() {
        _dragOffset = Offset.zero;
        _swipeAngle = 0.0;
        _swipeProgressRight = 0.0;
        _swipeProgressLeft = 0.0;
        _swipeProgressUp = 0.0;
      });
      _showAIExplanationBottomSheet(word.spelling, explanation);
      return;
    }

    // キャッシュがない場合のみローディングを表示してAPI通信
    setState(() {
      _dragOffset = Offset.zero;
      _swipeAngle = 0.0;
      _swipeProgressRight = 0.0;
      _swipeProgressLeft = 0.0;
      _swipeProgressUp = 0.0;
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
      explanation = "解説の取得に失敗しました。時間をおいて再度お試しください。";
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
            color: Color(0xFF141414), // Rule 5: Bottom sheet background Color(0xFF141414)
            borderRadius: BorderRadius.zero, // Rule 5: BorderRadius.zero
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI INSIGHT',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                spelling.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    explanation,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                      height: 1.8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.textPrimary, width: 2),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  child: Text(
                    'CLOSE',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
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
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(
          child: SpinKitPulse(color: AppTheme.textPrimary, size: 50),
        ),
      );
    }

    if (_currentIndex >= _learningWords.length) {
      return _buildFinishedScreen();
    }

    final currentWord = _learningWords[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${_learningWords.length}',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppTheme.textPrimary),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppTheme.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Swipe Overlays (Giant Text)
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_swipeProgressRight > 0)
                  Opacity(
                    opacity: _swipeProgressRight,
                    child: Text('MASTERED', style: GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.w900, color: AppTheme.success.withOpacity(0.3), letterSpacing: 2)),
                  ),
                if (_swipeProgressLeft > 0)
                  Opacity(
                    opacity: _swipeProgressLeft,
                    child: Text('WEAK', style: GoogleFonts.outfit(fontSize: 72, fontWeight: FontWeight.w900, color: AppTheme.error.withOpacity(0.3), letterSpacing: 2)),
                  ),
                if (_swipeProgressUp > 0)
                  Opacity(
                    opacity: _swipeProgressUp,
                    child: Text('AI', style: GoogleFonts.outfit(fontSize: 80, fontWeight: FontWeight.w900, color: AppTheme.primary.withOpacity(0.3), letterSpacing: 2)),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 16.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Current Card
                        GestureDetector(
                          onTap: _flipCard,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: AnimatedBuilder(
                            animation: _swipeController,
                            builder: (context, child) {
                              final offset = _swipeController.isAnimating
                                  ? _swipeAnimation.value
                                  : _dragOffset;
                              return Transform.translate(
                                offset: offset,
                                child: Transform.rotate(
                                  angle: _swipeAngle,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildCard(currentWord),
                          ),
                        ),

                        // AI Loading HUD
                        if (_isAILoading)
                          Positioned.fill(
                            child: Container(
                              color: const Color(0xFF0A0A0A).withOpacity(0.8),
                              child: const Center(
                                child: SpinKitDoubleBounce(color: AppTheme.textPrimary, size: 50),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSwipeLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Word word) {
    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, child) {
        // 3D Flip Matrix
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateY(_flipController.value * pi);

        final isFrontHalf = _flipController.value < 0.5;

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: isFrontHalf
              ? _buildCardContent(word, isFront: true)
              : Transform(
                  transform: Matrix4.identity()..rotateY(pi), // prevent text mirroring
                  alignment: Alignment.center,
                  child: _buildCardContent(word, isFront: false),
                ),
        );
      },
    );
  }

  Widget _buildCardContent(Word word, {required bool isFront}) {
    return Container(
      width: double.infinity,
      height: 500,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      decoration: const BoxDecoration(
        color: Colors.transparent, // NO CARDS
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isFront) ...[
            // Front side
            if (widget.config.direction == LanguageDirection.enToJa) ...[
              Text(
                word.spelling,
                style: GoogleFonts.outfit(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 36, color: AppTheme.info),
                onPressed: () => _speak(word.spelling),
                tooltip: '発音を聞く',
              ),
            ] else ...[
              Text(
                word.meaningJa,
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const Spacer(),
            Text(
              'TAP TO FLIP',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            )
          ] else ...[
            // Back side
            if (widget.config.direction == LanguageDirection.enToJa) ...[
              Text(
                word.spelling,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.meaningJa,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                word.meaningJa,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      word.spelling,
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 32, color: AppTheme.info),
                    onPressed: () => _speak(word.spelling),
                    tooltip: '発音を聞く',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 48),

            // Contextual Example Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3), width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTEXT',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (word.customExampleEn == null)
                    const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary),
                      ),
                    )
                  else ...[
                    Text(
                      word.customExampleEn!,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      word.customExampleJa!,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSwipeLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLegendItem(Icons.arrow_back_rounded, 'WEAK', AppTheme.error),
          _buildLegendItem(Icons.arrow_upward_rounded, 'AI', AppTheme.primary),
          _buildLegendItem(Icons.arrow_forward_rounded, 'MASTERED', AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'DONE',
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Session complete.\nTime for the next batch.',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  child: Text(
                    'RETURN',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 16),
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
