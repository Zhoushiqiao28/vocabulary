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
          SnackBar(
            content: Text(
              'ERROR SENDING MESSAGE',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppTheme.error,
          ),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity))),
        title: Text(
          'AI CHAT',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'CLEAR HISTORY',
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
                      padding: EdgeInsets.zero,
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location_rounded, color: AppTheme.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'TARGET VOCABULARY',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
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
                  label = 'WEAK';
                } else if (word.reviewedAt != null && 
                           word.reviewedAt!.year == today.year &&
                           word.reviewedAt!.month == today.month &&
                           word.reviewedAt!.day == today.day) {
                  chipColor = AppTheme.success;
                  label = 'TODAY';
                } else if (word.status == 0) {
                  chipColor = AppTheme.info;
                  label = 'NEW';
                } else {
                  chipColor = AppTheme.warning;
                  label = 'REVIEW';
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: chipColor.withOpacity(AppTheme.opStrong)),
                    color: chipColor.withOpacity(AppTheme.opSubtle),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        word.spelling.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: chipColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        word.meaningJa,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (label.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          color: chipColor,
                          child: Text(
                            label,
                            style: GoogleFonts.outfit(
                              color: AppTheme.background,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
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
            const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 64),
            const SizedBox(height: 24),
            Text(
              'NO MESSAGES YET',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'START TYPING TO INITIATE CONVERSATION',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, int index, bool isUser) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.background : AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity),
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
                  style: GoogleFonts.outfit(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Flexible(
                child: Text(
                  msg.text,
                  style: GoogleFonts.outfit(
                    color: isUser ? AppTheme.textSecondary : AppTheme.textPrimary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: isUser ? TextAlign.right : TextAlign.left,
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 16),
                Text(
                  'YOU',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
          
          if (!isUser && msg.needsCorrection && msg.correctedText != null) ...[
            const SizedBox(height: 24),
            _buildCorrectionAccordion(msg, index),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionAccordion(ChatMessage msg, int index) {
    final isExpanded = _expandedCorrectionIndices.contains(index);
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppTheme.info.withOpacity(AppTheme.opStrong)),
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
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.spellcheck_rounded, color: AppTheme.info, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'CORRECTION AVAILABLE',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.info,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    color: AppTheme.info,
                    size: 20,
                  )
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: AppTheme.info.withOpacity(AppTheme.opMedium), height: 1),
                  const SizedBox(height: 12),
                  
                  Text('CORRECTED:', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.info, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    msg.correctedText!,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (msg.explanation != null) ...[
                    Text('EXPLANATION:', style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      msg.explanation!,
                      style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI',
            style: GoogleFonts.outfit(
              color: AppTheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(
            height: 24,
            child: SpinKitThreeBounce(color: AppTheme.primary, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity))),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'TYPE MESSAGE...',
                hintStyle: GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(AppTheme.opBold), fontSize: 14, letterSpacing: 1),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Colors.white.withOpacity(AppTheme.borderSubtleOpacity)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Material(
            color: AppTheme.primary,
            borderRadius: BorderRadius.zero,
            child: InkWell(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
