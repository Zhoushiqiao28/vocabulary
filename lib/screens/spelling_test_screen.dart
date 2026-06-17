import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SpellingTestScreen extends ConsumerStatefulWidget {
  const SpellingTestScreen({super.key});

  @override
  ConsumerState<SpellingTestScreen> createState() => _SpellingTestScreenState();
}

class _SpellingTestScreenState extends ConsumerState<SpellingTestScreen> {
  List<Word> _testWords = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _hasChecked = false;
  bool _isCorrect = false;
  bool _showHint = false;

  int _score = 0;
  List<Word> _wrongWords = [];

  @override
  void initState() {
    super.initState();
    _generateTest();
  }

  void _generateTest() {
    final allWords = ref.read(wordListProvider);
    if (allWords.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final shuffled = List<Word>.from(allWords)..shuffle();
    _testWords = shuffled.take(10).toList();

    setState(() {
      _isLoading = false;
    });

    _loadQuestion();
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
    final correctAnswer = targetWord.spelling.trim().toLowerCase();

    final isCorrect = answer == correctAnswer;

    setState(() {
      _isCorrect = isCorrect;
      _hasChecked = true;
      _focusNode.unfocus();

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
  }

  void _nextQuestion() {
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
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (_testWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('スペルテスト')),
        body: const Center(
          child: Text('テストを開始できる単語がありません。'),
        ),
      );
    }

    if (_currentIndex >= _testWords.length) {
      return _buildFinishedScreen();
    }

    final targetWord = _testWords[_currentIndex];
    final wordLength = targetWord.spelling.length;
    
    final hintText = targetWord.spelling.isNotEmpty
        ? targetWord.spelling[0] + ' ' + ('_ ' * (wordLength - 1))
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('スペルテスト (${_currentIndex + 1}/${_testWords.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _testWords.length,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 32),

              Container(
                height: 180,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'この意味を持つ英単語は？',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      targetWord.meaningJa,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_showHint || _hasChecked)
                Center(
                  child: Text(
                    _hasChecked ? targetWord.spelling : hintText,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: _hasChecked
                          ? (_isCorrect ? Colors.tealAccent : Colors.redAccent)
                          : AppTheme.secondary,
                    ),
                  ),
                )
              else
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showHint = true;
                      });
                    },
                    icon: const Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.secondary),
                    label: const Text(
                      '最初の1文字ヒントを表示',
                      style: TextStyle(color: AppTheme.secondary, fontSize: 13),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

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
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'ここにスペルを入力...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.3), fontSize: 16),
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              if (!_hasChecked)
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _checkAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'スペルをチェック',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCorrect ? Colors.teal : AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _currentIndex + 1 == _testWords.length ? '結果を確認' : '次へ進む',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
            ],
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
                'テスト完了！',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'スコア: $_score / ${_testWords.length}',
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word.spelling,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  word.meaningJa,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            const Icon(Icons.keyboard_arrow_right_rounded, color: Colors.white24),
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
