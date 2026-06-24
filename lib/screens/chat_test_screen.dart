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
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<int> _expandedCorrectionIndices = [];

  List<Word> _targetWords = [];

  @override
  void initState() {
    super.initState();
    _initTargets();
  }

  void _initTargets() {
    final words = ref.read(wordListProvider);
    // Find up to 5 words to practice (prioritize weak or unlearned)
    final weak = words.where((e) => e.status == 2).toList();
    final newWords = words.where((e) => e.status == 0).toList();
    
    final targets = [...weak, ...newWords].take(5).toList();
    setState(() {
      _targetWords = targets;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiVocaChatProvider.notifier).setTargetWords(targets);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();

    await ref.read(aiVocaChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(aiVocaChatProvider);
    final isAILoading = chatHistory.isNotEmpty && chatHistory.last.role == 'user';

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('RADIO AI DIALOGUE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear history',
            onPressed: () {
              ref.read(aiVocaChatProvider.notifier).clearHistory();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Target Words header bar
            if (_targetWords.isNotEmpty) _buildTargetWordsBar(),
            const Divider(height: 1, thickness: 1),

            // Chat Messages area
            Expanded(
              child: chatHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: chatHistory.length + (isAILoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == chatHistory.length && isAILoading) {
                          return _buildAILoadingIndicator();
                        }
                        final msg = chatHistory[index];
                        return _buildMessageRow(msg, index, msg.role == 'user');
                      },
                    ),
            ),
            const Divider(height: 1, thickness: 1),

            // Input Bar at bottom
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetWordsBar() {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TARGET PRACTICE VOCABULARY',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _targetWords.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final word = _targetWords[index];
                
                Color chipColor;
                String label = '';

                if (word.status == 2) {
                  chipColor = AppTheme.error;
                  label = 'Weak';
                } else if (word.reviewedAt != null && 
                           word.reviewedAt!.year == today.year &&
                           word.reviewedAt!.month == today.month &&
                           word.reviewedAt!.day == today.day) {
                  chipColor = AppTheme.success;
                  label = 'Today';
                } else if (word.status == 0) {
                  chipColor = AppTheme.info;
                  label = 'New';
                } else {
                  chipColor = AppTheme.warning;
                  label = 'Review';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: chipColor.withOpacity(0.3)),
                    color: chipColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word.spelling,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        word.meaningJa,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
            const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Start typing below to initiate your practice dialogue.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, int index, bool isUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Text(
                  'AI',
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  msg.text,
                  style: GoogleFonts.inter(
                    color: isUser ? AppTheme.textSecondary : AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                Text(
                  'YOU',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          
          if (!isUser && msg.needsCorrection && msg.correctedText != null) ...[
            const SizedBox(height: 14),
            _buildCorrectionBox(msg, index),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionBox(ChatMessage msg, int index) {
    final isExpanded = _expandedCorrectionIndices.contains(index);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderColor),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.spellcheck_rounded, color: AppTheme.success, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'GRAMMAR ADVICE AVAILABLE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    color: AppTheme.textSecondary,
                    size: 16,
                  )
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: AppTheme.background.withOpacity(0.3),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RECOMENDED SYNTAX:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.correctedText!,
                    style: GoogleFonts.inter(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (msg.explanation != null && msg.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'EXPLANATION:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.explanation!,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          )
        ],
      ),
    );
  }

  Widget _buildAILoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(
            'AI',
            style: GoogleFonts.inter(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 12),
          const SpinKitThreeBounce(color: AppTheme.textSecondary, size: 14),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: AppTheme.background,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Type practice sentence...',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
