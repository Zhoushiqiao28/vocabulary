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
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'AI会話練習',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
            tooltip: '会話をリセット',
            onPressed: () {
              ref.read(aiVocaChatProvider.notifier).clearHistory();
            },
          ),
          const SizedBox(width: AppTheme.sp4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Target Words header bar
            if (_targetWords.isNotEmpty) _buildTargetWordsBar(),

            // Chat Messages area
            Expanded(
              child: chatHistory.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sp16,
                        vertical: AppTheme.sp12,
                      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp16,
        vertical: AppTheme.sp12,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '練習する単語',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.sp8),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _targetWords.length,
              separatorBuilder: (context, index) => const SizedBox(width: AppTheme.sp8),
              itemBuilder: (context, index) {
                final word = _targetWords[index];

                Color chipColor;
                String label;

                if (word.status == 2) {
                  chipColor = AppTheme.error;
                  label = '苦手';
                } else if (word.reviewedAt != null &&
                    word.reviewedAt!.year == today.year &&
                    word.reviewedAt!.month == today.month &&
                    word.reviewedAt!.day == today.day) {
                  chipColor = AppTheme.success;
                  label = '今日学習';
                } else if (word.status == 0) {
                  chipColor = AppTheme.info;
                  label = '未習得';
                } else {
                  chipColor = AppTheme.warning;
                  label = '復習';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp8, vertical: 0),
                  alignment: Alignment.center,
                  decoration: AppTheme.statusChipDecoration(color: chipColor),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word.spelling,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.sp4),
                      Text(
                        word.meaningJa,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.sp4),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          color: chipColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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
        padding: const EdgeInsets.all(AppTheme.sp48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.textMuted,
              size: 48,
            ),
            const SizedBox(height: AppTheme.sp16),
            Text(
              'まだ会話がありません',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.sp8),
            Text(
              'メッセージを送って会話を始めましょう',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg, int index, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Role label
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sp4),
            child: Text(
              isUser ? 'あなた' : 'AI',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          // Message bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sp16,
              vertical: AppTheme.sp12,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? AppTheme.surface
                  : AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: isUser
                    ? AppTheme.borderColor
                    : AppTheme.primary.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          // Correction accordion
          if (!isUser && msg.needsCorrection && msg.correctedText != null) ...[
            const SizedBox(height: AppTheme.sp8),
            _buildCorrectionBox(msg, index),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionBox(ChatMessage msg, int index) {
    final isExpanded = _expandedCorrectionIndices.contains(index);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.78,
      ),
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.info.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.sp12,
                vertical: AppTheme.sp8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high_rounded, color: AppTheme.info, size: 14),
                      const SizedBox(width: AppTheme.sp8),
                      Text(
                        '文法の修正',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.info,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp12, 0, AppTheme.sp12, AppTheme.sp12,
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppTheme.borderColor, height: 1),
                  const SizedBox(height: AppTheme.sp12),
                  Text(
                    '修正文:',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.sp4),
                  Text(
                    msg.correctedText!,
                    style: GoogleFonts.outfit(
                      color: AppTheme.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (msg.explanation != null && msg.explanation!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.sp12),
                    Text(
                      '解説:',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp4),
                    Text(
                      msg.explanation!,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 150),
          ),
        ],
      ),
    );
  }

  Widget _buildAILoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.sp12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.sp4),
            child: Text(
              'AI',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sp16,
              vertical: AppTheme.sp12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const SpinKitThreeBounce(
              color: AppTheme.primary,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.sp12,
        vertical: AppTheme.sp8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '日本語や英語で入力...',
                hintStyle: GoogleFonts.outfit(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp16,
                  vertical: AppTheme.sp12,
                ),
                filled: true,
                fillColor: AppTheme.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: const BorderSide(color: AppTheme.borderColor, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.sp8),
          SizedBox(
            width: 44,
            height: 44,
            child: ElevatedButton(
              onPressed: _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                elevation: 0,
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
