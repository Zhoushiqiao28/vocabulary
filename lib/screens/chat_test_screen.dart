import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class ChatTestScreen extends ConsumerStatefulWidget {
  const ChatTestScreen({super.key});

  @override
  ConsumerState<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends ConsumerState<ChatTestScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  
  final Set<int> _expandedCorrectionIndices = {};
  List<Word> _targetWords = [];

  @override
  void initState() {
    super.initState();
    _selectTargetWords();
  }

  void _selectTargetWords() {
    final allWords = ref.read(wordListProvider);
    if (allWords.isEmpty) return;

    final weakWords = allWords.where((w) => w.status == 2).toList()..shuffle();
    
    final today = DateTime.now();
    final todayWords = allWords.where((w) {
      if (w.reviewedAt == null) return false;
      return w.reviewedAt!.year == today.year &&
             w.reviewedAt!.month == today.month &&
             w.reviewedAt!.day == today.day;
    }).toList()..shuffle();
    
    final unlearnedWords = allWords.where((w) => w.status == 0).toList()..shuffle();
    final learnedWords = allWords.where((w) => w.status == 1).toList()..shuffle();

    final selected = <Word>{};

    selected.addAll(weakWords.take(3));
    selected.addAll(todayWords.take(3));
    selected.addAll(unlearnedWords.take(2));
    selected.addAll(learnedWords.take(2));

    if (selected.length < 5) {
      final remaining = List<Word>.from(allWords)..shuffle();
      for (final w in remaining) {
        if (selected.length >= 5) break;
        selected.add(w);
      }
    }

    _targetWords = selected.toList();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(aiVocaChatProvider.notifier).setTargetWords(_targetWords);
      }
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    setState(() {
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final chatNotifier = ref.read(aiVocaChatProvider.notifier);
      await chatNotifier.sendMessage(text);
      ref.read(userProfileProvider.notifier).recordLearningActivity();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メッセージ送信エラー')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(aiVocaChatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '💬 AI特訓チャット',
          style: GoogleFonts.outfit(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: '会話履歴をクリア',
            onPressed: () {
              ref.read(aiVocaChatProvider.notifier).clearHistory();
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTargetWordHeader(),

            Expanded(
              child: chatHistory.isEmpty && !_isSending
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: chatHistory.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatHistory.length && _isSending) {
                          return _buildAILoadingBubble();
                        }
                        
                        final msg = chatHistory[index];
                        final isUser = msg.role == 'user';
                        
                        return _buildMessageBubble(msg, index, isUser);
                      },
                    ),
            ),

            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetWordHeader() {
    if (_targetWords.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary, size: 14),
              const SizedBox(width: 6),
              Text(
                '今日の暗記ターゲット単語（会話で使ってみましょう）',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _targetWords.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final word = _targetWords[index];
                
                Color badgeBg = Colors.white10;
                Color textColor = AppTheme.textPrimary;
                String label = '';

                if (word.status == 2) {
                  badgeBg = Colors.redAccent.withOpacity(0.12);
                  textColor = Colors.redAccent;
                  label = '苦手';
                } else if (word.reviewedAt != null && 
                           word.reviewedAt!.year == today.year &&
                           word.reviewedAt!.month == today.month &&
                           word.reviewedAt!.day == today.day) {
                  badgeBg = Colors.teal.withOpacity(0.12);
                  textColor = Colors.tealAccent;
                  label = '今日学習';
                } else if (word.status == 0) {
                  badgeBg = AppTheme.primary.withOpacity(0.15);
                  textColor = AppTheme.secondary;
                  label = '未習得';
                } else {
                  badgeBg = Colors.orangeAccent.withOpacity(0.12);
                  textColor = Colors.orangeAccent;
                  label = '復習';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: textColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word.spelling,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${word.meaningJa})',
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                      if (label.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(color: textColor, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withOpacity(0.05),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'チャット練習を始めましょう！',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '「Hello!」などと入力して送信すると、AIから英会話がスタートします。',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, int index, bool isUser) {
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary,
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
              ),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? Colors.white.withOpacity(0.06) : AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isUser ? Colors.white.withOpacity(0.03) : AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, height: 1.4),
                ),
              ),
            ),
          ],
        ),
        
        if (!isUser && msg.needsCorrection && msg.correctedText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 40.0, bottom: 12.0),
            child: _buildCorrectionAccordion(msg, index),
          )
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCorrectionAccordion(ChatMessage msg, int index) {
    final isExpanded = _expandedCorrectionIndices.contains(index);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1428),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCorrectionIndices.remove(index);
                } else {
                  _expandedCorrectionIndices.add(index);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.spellcheck_rounded, color: AppTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'AIによる表現の修正があります',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppTheme.accent,
                    size: 20,
                  )
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  
                  const Text('修正後：', style: TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    msg.correctedText!,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  if (msg.explanation != null) ...[
                    const Text('解説：', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      msg.explanation!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          )
        ],
      ),
    );
  }

  Widget _buildAILoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
            ),
            child: const SizedBox(
              width: 40,
              height: 20,
              child: Center(
                child: SpinKitThreeBounce(color: AppTheme.secondary, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: '英文メッセージを入力してください...',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.4), fontSize: 14),
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _sendMessage,
            ),
          )
        ],
      ),
    );
  }
}
