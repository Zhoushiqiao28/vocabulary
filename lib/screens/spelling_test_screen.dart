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
        appBar: AppBar(title: const Text('SPELLING ASSESSMENT')),
        body: Center(
          child: Text(
            'STATUS: NO WORDS MATCHED CONFIGURATION.',
            style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary),
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
            'SPELLING_DICTATION // MODULE_${_currentIndex + 1}_OF_${_testWords.length}',
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
                  final progress = (_currentIndex + 1) / _testWords.length;
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

              // VFD Glass display question
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
                        targetWord.meaningJa,
                        style: GoogleFonts.shareTechMono(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
        
                      if (_showHint || _hasChecked)
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (_hasChecked ? targetWord.spelling : hintText).toUpperCase(),
                                style: GoogleFonts.spaceMono(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: _hasChecked
                                      ? (_isCorrect ? AppTheme.success : AppTheme.error)
                                      : AppTheme.primary,
                                ),
                              ),
                              if (_hasChecked) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.textSecondary),
                                  onPressed: () => _speak(targetWord.spelling),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        TactileButton(
                          width: 140,
                          height: 32,
                          onPressed: () {
                            setState(() {
                              _showHint = true;
                            });
                            _speak(targetWord.spelling);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.help_outline_rounded, size: 12, color: AppTheme.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'SHOW FIRST LETTER',
                                style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
        
              // Green prompt terminal text field input box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                      style: GoogleFonts.spaceMono(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _hasChecked 
                            ? (_isCorrect ? AppTheme.success : AppTheme.error)
                            : AppTheme.primary,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        prefixText: 'SYS_IN > ',
                        prefixStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 13),
                        hintText: 'TYPE SPELLING HERE...',
                        hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TactileButton(
                      height: 48,
                      onPressed: _hasChecked ? _nextQuestion : _checkAnswer,
                      color: _hasChecked 
                          ? (_isCorrect ? AppTheme.success : AppTheme.error)
                          : AppTheme.primary,
                      ledColor: Colors.white,
                      isLedOn: true,
                      child: Text(
                        _hasChecked ? 'NEXT CHANNEL [Enter]' : 'EXECUTE INPUT [Enter]',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.displayBg,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
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
                'SPELLING COMPLETE // OUTCOME',
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
                'SCORE: ${_score.toString().padLeft(2, '0')} / ${_testWords.length.toString().padLeft(2, '0')}',
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
                  '// WEAK CHANNELS LOGGED:',
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
                                style: GoogleFonts.spaceMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
