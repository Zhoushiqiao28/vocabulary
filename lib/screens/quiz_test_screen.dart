import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:async';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class QuizTestScreen extends ConsumerStatefulWidget {
  const QuizTestScreen({super.key});

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
  List<Word> _wrongWords = [];

  final FocusNode _keyboardFocusNode = FocusNode();
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _transitionTimer?.cancel();
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

    final shuffled = List<Word>.from(allWords)..shuffle();
    _quizWords = shuffled.take(10).toList();

    setState(() {
      _isLoading = false;
    });

    _loadQuestion();
  }

  void _loadQuestion() {
    if (_currentIndex >= _quizWords.length) return;

    final targetWord = _quizWords[_currentIndex];
    final allWords = ref.read(wordListProvider);

    final options = <String>{targetWord.meaningJa};
    final random = Random();

    while (options.length < 4) {
      final randomWord = allWords[random.nextInt(allWords.length)];
      if (randomWord.spelling != targetWord.spelling) {
        options.add(randomWord.meaningJa);
      }
    }

    setState(() {
      _currentOptions = options.toList()..shuffle();
      _selectedOption = null;
      _hasAnswered = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  void _answer(String option) {
    if (_hasAnswered) return;

    final targetWord = _quizWords[_currentIndex];
    final isCorrect = option == targetWord.meaningJa;

    setState(() {
      _selectedOption = option;
      _hasAnswered = true;
      if (isCorrect) {
        _score++;
        if (targetWord.status != 1) {
          ref.read(wordListProvider.notifier).updateWordStatus(targetWord.id, 1);
        }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_quizWords.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('択一クイズ')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'クイズを開始するには、少なくとも4つ以上の単語が登録されている必要があります。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_currentIndex >= _quizWords.length) {
      return _buildFinishedScreen();
    }

    final targetWord = _quizWords[_currentIndex];

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
          if (_hasAnswered) {
            _nextQuestion();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('択一クイズ (${_currentIndex + 1}/${_quizWords.length})'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _quizWords.length,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 48),
  
                Expanded(
                  flex: 2,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      targetWord.spelling,
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
  
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _currentOptions.map((option) {
                      final isSelected = _selectedOption == option;
                      final isCorrectOption = option == targetWord.meaningJa;
                      
                      Color cardColor = AppTheme.surface;
                      Color borderColor = Colors.white.withOpacity(0.05);
                      Color textColor = AppTheme.textPrimary;
  
                      if (_hasAnswered) {
                        if (isCorrectOption) {
                          cardColor = Colors.teal.withOpacity(0.12);
                          borderColor = Colors.teal;
                          textColor = Colors.tealAccent;
                        } else if (isSelected) {
                          cardColor = Colors.redAccent.withOpacity(0.12);
                          borderColor = Colors.redAccent;
                          textColor = Colors.redAccent;
                        }
                      }
  
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _answer(option),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 1.5),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
  
                if (_hasAnswered)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentIndex + 1 == _quizWords.length ? '結果を確認' : '次へ進む',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.1),
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: AppTheme.primary, size: 40),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'クイズ完了！',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'スコア: $_score / ${_quizWords.length}',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              if (_wrongWords.isNotEmpty) ...[
                Text(
                  '❌ 間違えた単語（自動で「覚えてない」に登録されました）',
                  style: TextStyle(color: Colors.redAccent[100], fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 12),
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    itemCount: _wrongWords.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final word = _wrongWords[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.03)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              word.spelling,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              word.meaningJa,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                const Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      '素晴らしい！全問正解です！🌟',
                      style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              ],
              const Spacer(),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('閉じる'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
