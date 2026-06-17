import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class ChatTestScreen extends ConsumerStatefulWidget {
  final Word targetWord;

  const ChatTestScreen({super.key, required this.targetWord});

  @override
  ConsumerState<ChatTestScreen> createState() => _ChatTestScreenState();
}

class _ChatTestScreenState extends ConsumerState<ChatTestScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  
  final Set<int> _expandedCorrectionIndices = {};

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
      final chatNotifier = ref.read(chatProviderFamily(widget.targetWord.spelling).notifier);
      await chatNotifier.sendMessage(text);
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
    final chatHistory = ref.watch(chatProviderFamily(widget.targetWord.spelling));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '💬 AI対話テスト: ${widget.targetWord.spelling}',
          style: GoogleFonts.outfit(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: '会話履歴をクリア',
            onPressed: () {
              ref.read(chatProviderFamily(widget.targetWord.spelling).notifier).clearHistory();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: AppTheme.surface,
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: AppTheme.secondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                children: [
                  const TextSpan(text: '文中に '),
                  TextSpan(
                    text: widget.targetWord.spelling,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondary,
                    ),
                  ),
                  TextSpan(text: '（${widget.targetWord.meaningJa}）を含めて発言してください。'),
                ],
              ),
            ),
          )
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
