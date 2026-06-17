import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:math';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class CardLearningScreen extends ConsumerStatefulWidget {
  const CardLearningScreen({super.key});

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _initWords() async {
    final words = ref.read(wordListProvider);
    final notMastered = words.where((e) => e.status != 1).toList();
    if (notMastered.isEmpty) {
      _learningWords = words.take(10).toList();
    } else {
      notMastered.shuffle();
      _learningWords = notMastered.take(10).toList();
    }

    setState(() {
      _isLoading = false;
    });

    if (_learningWords.isNotEmpty) {
      _prefetchExamples(0);
    }
  }

  Future<void> _prefetchExamples(int index) async {
    if (index >= _learningWords.length) return;
    
    final currentWord = _learningWords[index];
    if (currentWord.customExampleEn == null) {
      _fetchExampleForWord(index);
    }

    final nextIndex = index + 1;
    if (nextIndex < _learningWords.length) {
      final nextWord = _learningWords[nextIndex];
      if (nextWord.customExampleEn == null) {
        _fetchExampleForWord(nextIndex);
      }
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
      _swipeController.reset();
      _flipController.reset();

      _prefetchExamples(_currentIndex);
    }
  }

  Future<void> _askAIAboutWord() async {
    setState(() {
      _dragOffset = Offset.zero;
      _swipeAngle = 0.0;
      _swipeProgressRight = 0.0;
      _swipeProgressLeft = 0.0;
      _swipeProgressUp = 0.0;
      _isAILoading = true;
    });

    final word = _learningWords[_currentIndex];
    final gemini = ref.read(geminiServiceProvider);
    String explanation = word.coreNuance ?? '';
    
    if (explanation.isEmpty) {
      explanation = await gemini.getWordNuance(word.spelling, word.meaningJa);
      ref.read(wordListProvider.notifier).updateWordDetails(word.id, coreNuance: explanation);
      if (mounted) {
        setState(() {
          _learningWords[_currentIndex] = word.copyWith(coreNuance: explanation);
        });
      }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'AI ニュアンス・語源解説',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '対象単語: $spelling',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    explanation,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('閉じる'),
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
        body: Center(
          child: SpinKitPulse(color: AppTheme.primary, size: 50),
        ),
      );
    }

    if (_currentIndex >= _learningWords.length) {
      return _buildFinishedScreen();
    }

    final currentWord = _learningWords[_currentIndex];

    Color overlayColor = Colors.transparent;
    if (_swipeProgressRight > 0) {
      overlayColor = Colors.teal.withOpacity(_swipeProgressRight * 0.15);
    } else if (_swipeProgressLeft > 0) {
      overlayColor = Colors.redAccent.withOpacity(_swipeProgressLeft * 0.15);
    } else if (_swipeProgressUp > 0) {
      overlayColor = AppTheme.primary.withOpacity(_swipeProgressUp * 0.15);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '暗記カード (${_currentIndex + 1}/${_learningWords.length})',
          style: GoogleFonts.outfit(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
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
          // Background Color Overlay
          AnimatedContainer(
            duration: Duration(milliseconds: _isDragging ? 0 : 300),
            color: overlayColor,
            width: double.infinity,
            height: double.infinity,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Next card (visual depth)
                        if (_currentIndex + 1 < _learningWords.length)
                          Transform.scale(
                            scale: 0.95,
                            child: Transform.translate(
                              offset: const Offset(0, 15),
                              child: _buildCard(_learningWords[_currentIndex + 1], isDummy: true),
                            ),
                          ),

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
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Center(
                                child: SpinKitDoubleBounce(color: AppTheme.secondary, size: 50),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  '💡 カードをタップして裏返す',
                  style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                
                _buildSwipeLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Word word, {bool isDummy = false}) {
    if (isDummy) {
      return _buildCardContent(word, isFront: true);
    }

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
      height: 420,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isFront ? Colors.white.withOpacity(0.08) : AppTheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isFront) ...[
            // Front side: Just the English word
            Text(
              word.spelling,
              style: GoogleFonts.outfit(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'タップして意味を確認',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            )
          ] else ...[
            // Back side: Japanese, Core Nuance, AI Example
            Text(
              word.spelling,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              word.meaningJa,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // AI interest sentence
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: AppTheme.glassBoxDecoration(color: AppTheme.secondary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'AI興味関心例文',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (word.customExampleEn == null)
                    const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondary),
                      ),
                    )
                  else ...[
                    Text(
                      word.customExampleEn!,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
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
          ]
        ],
      ),
    );
  }

  Widget _buildSwipeLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(Icons.arrow_back_rounded, '覚えてない', Colors.redAccent),
        _buildLegendItem(Icons.arrow_upward_rounded, 'AI解説', AppTheme.primary),
        _buildLegendItem(Icons.arrow_forward_rounded, '覚えた', Colors.teal),
      ],
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withOpacity(0.1),
                  border: Border.all(color: AppTheme.secondary, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.secondary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'セッション完了！ 🎉',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '今日のカード暗記が完了しました。\nまた次の10語を学びましょう！',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('戻る'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
