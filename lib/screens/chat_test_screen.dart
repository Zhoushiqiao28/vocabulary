import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:math';
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
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            tooltip: 'Reset transceivers',
            onPressed: () {
              ref.read(aiVocaChatProvider.notifier).clearHistory();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Oscilloscope screen / wave display
            _buildOscilloscopePanel(),
            const Divider(height: 1, thickness: 1),

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

  Widget _buildOscilloscopePanel() {
    return Container(
      height: 48,
      color: AppTheme.displayBg,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success,
                  boxShadow: [
                    BoxShadow(color: AppTheme.success, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LINK ACTIVE // CH_443.2HZ',
                style: GoogleFonts.shareTechMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: CustomPaint(
                painter: OscilloscopePainter(),
                child: Container(),
              ),
            ),
          ),
          Text(
            'RX/TX_LOG',
            style: GoogleFonts.shareTechMono(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetWordsBar() {
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TARGET PRACTICE CHANNEL CHIPS',
            style: GoogleFonts.shareTechMono(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _targetWords.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderColor),
                    color: AppTheme.displayBg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status LED dot
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: chipColor,
                          boxShadow: [
                            BoxShadow(color: chipColor, blurRadius: 2),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        word.spelling.toUpperCase(),
                        style: GoogleFonts.shareTechMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        word.meaningJa,
                        style: GoogleFonts.shareTechMono(
                          fontSize: 9,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.shareTechMono(
                          color: chipColor,
                          fontSize: 8,
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
            const Icon(Icons.radio_rounded, color: AppTheme.textMuted, size: 36),
            const SizedBox(height: 12),
            Text(
              'SIGNAL EMPTY // NO DIALOG RECORDED',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SEND A TRANSMISSION TO INITIALIZE DIALOG SYSTEM.',
              style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  '[ RECEIVE // RX ]',
                  style: GoogleFonts.shareTechMono(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Text(
                  msg.text,
                  style: GoogleFonts.shareTechMono(
                    color: isUser ? AppTheme.textSecondary : AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                Text(
                  '[ TRANSMIT // TX ]',
                  style: GoogleFonts.shareTechMono(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
          
          if (!isUser && msg.needsCorrection && msg.correctedText != null) ...[
            const SizedBox(height: 10),
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
        color: AppTheme.displayBg,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_circle_rounded, color: AppTheme.warning, size: 12),
                      const SizedBox(width: 8),
                      Text(
                        'DIAGNOSTIC ADVISE // GRAMMAR WARNING',
                        style: GoogleFonts.shareTechMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    color: AppTheme.textSecondary,
                    size: 14,
                  )
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppTheme.surface.withOpacity(0.5),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '// CORRECTED SYNTAX:',
                    style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.correctedText!,
                    style: GoogleFonts.shareTechMono(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (msg.explanation != null && msg.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '// ANALYTICAL LOG:',
                      style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.explanation!,
                      style: GoogleFonts.shareTechMono(color: AppTheme.textPrimary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 150),
          )
        ],
      ),
    );
  }

  Widget _buildAILoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            '[ RECEIVE // RX ]',
            style: GoogleFonts.shareTechMono(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 12),
          const SpinKitThreeBounce(color: AppTheme.textSecondary, size: 10),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.shareTechMono(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                prefixText: 'TX_DATA > ',
                prefixStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 13),
                hintText: 'TYPE PRACTICE TRANSLATION...',
                hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                fillColor: AppTheme.displayBg,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TactileButton(
            width: 70,
            height: 38,
            onPressed: _send,
            color: AppTheme.primary,
            child: Text(
              'SEND',
              style: GoogleFonts.shareTechMono(
                fontWeight: FontWeight.bold,
                color: AppTheme.displayBg,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// draws a high-frequency sine-wave/noise monitor to look like analog oscilloscope
class OscilloscopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double midY = size.height / 2;
    final int points = 80;
    final double stepX = size.width / points;

    final random = Random();
    path.moveTo(0, midY);
    for (int i = 1; i <= points; i++) {
      final double x = i * stepX;
      // High frequency wave combined with noise spikes
      final double wave1 = sin(i * 0.6) * (size.height * 0.25);
      final double wave2 = cos(i * 0.15) * (size.height * 0.15);
      final double noise = (random.nextDouble() - 0.5) * (size.height * 0.2);
      path.lineTo(x, midY + wave1 + wave2 + noise);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
