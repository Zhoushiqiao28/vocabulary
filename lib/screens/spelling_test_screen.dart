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
  List<Word> _wrongWords = [];

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
        // Update SRS status under SM-2 (1: Mastered)
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
      } else {
        _wrongWords.add(targetWord);
        // Update SRS status under SM-2 (2: Weak)
        ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 2);
      }
    });

    _speak(targetWord.spelling);

    // Auto navigate after 2s
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
        body: Center(child: SpinKitPulse(color: AppTheme.textSecondary, size: 40)),
      );
    }

    if (_testWords.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Spelling Test')),
        body: const Center(
          child: Text('No words match your selected configuration.'),
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
          title: Text('SPELLING ASSESSMENT (${_currentIndex + 1}/${_testWords.length})'),
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
                value: (_currentIndex + 1) / _testWords.length,
                backgroundColor: AppTheme.borderColor,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 2,
              ),
              const Spacer(),

              // Text Question / Answer Feedback
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        targetWord.meaningJa,
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
        
                      if (_showHint || _hasChecked)
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _hasChecked ? targetWord.spelling : hintText,
                                style: GoogleFonts.inter(
                                  fontSize: 24,
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
                                  icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppTheme.textSecondary),
                                  onPressed: () => _speak(targetWord.spelling),
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showHint = true;
                            });
                            _speak(targetWord.spelling);
                          },
                          icon: const Icon(Icons.help_outline_rounded, size: 14),
                          label: const Text('Show First Letter', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
        
              // Sleek outline input box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _checkAnswer(),
                  enabled: !_hasChecked,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: 'Type spelling here...',
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                'SPELLING COMPLETE',
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
                '$_score / ${_testWords.length}',
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
                  'WORDS TO REVIEW',
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
                        'ALL CORRECT',
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
