import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/learning_calendar_dialog.dart';
import 'card_learning_screen.dart';
import 'quiz_test_screen.dart';
import 'spelling_test_screen.dart';
import 'chat_test_screen.dart';
import 'settings_screen.dart';
import 'word_list_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _startLearning(
    BuildContext context,
    int totalWordsCount, {
    required bool isTest,
    required bool isSpelling,
    required Widget Function(LearningConfig) screenBuilder,
  }) async {
    final config = await showModalBottomSheet<LearningConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LearningConfigBottomSheet(
        isTest: isTest,
        isSpelling: isSpelling,
        totalWordsCount: totalWordsCount,
      ),
    );

    if (config != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => screenBuilder(config)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final words = ref.watch(wordListProvider);
    final masteredCount = words.where((e) => e.status == 1).toList().length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Strict dark canvas
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(context, profile, words, masteredCount)
            : _buildNarrowLayout(context, profile, words, masteredCount),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // NARROW LAYOUT (Mobile < 700px)
  // ═══════════════════════════════════════════════
  Widget _buildNarrowLayout(BuildContext context, dynamic profile, List<Word> words, int masteredCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _buildHeader(context, profile),
        ),

        // Center: Giant Progress Ring
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGiantProgressRing(profile, words),
                const SizedBox(height: 32),
                _buildMinimalStatsLine(profile, masteredCount),
              ],
            ),
          ),
        ),

        // Bottom Actions (Full bleed)
        _buildSessionBand(context, words.length, profile),
        _buildModeList(context, words.length),
        
        // Footer
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildFooter(masteredCount, words.length),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // WIDE LAYOUT (Desktop ≥ 700px)
  // ═══════════════════════════════════════════════
  Widget _buildWideLayout(BuildContext context, dynamic profile, List<Word> words, int masteredCount) {
    return Row(
      children: [
        // Left Side: Typography and Ring
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                child: _buildHeader(context, profile),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGiantProgressRing(profile, words),
                      const SizedBox(height: 32),
                      _buildMinimalStatsLine(profile, masteredCount),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Divider
        Container(
          width: 1,
          color: Colors.white.withOpacity(0.05),
        ),
        // Right Side: Actions
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              _buildSessionBand(context, words.length, profile),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildModeList(context, words.length),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                child: _buildFooter(masteredCount, words.length),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // COMPONENTS
  // ═══════════════════════════════════════════════

  // ── Header (Tiny, minimal) ──
  Widget _buildHeader(BuildContext context, dynamic profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Good evening, ${profile.name}',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: 0.3,
          ),
        ),
        Row(
          children: [
            _buildTinyIcon(context, Icons.menu_book_rounded, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WordListScreen()));
            }),
            const SizedBox(width: 16),
            _buildTinyIcon(context, Icons.settings_rounded, () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
            }),
          ],
        )
      ],
    );
  }

  Widget _buildTinyIcon(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: Colors.white.withOpacity(0.4)),
    );
  }

  // ── Giant Progress Ring ──
  Widget _buildGiantProgressRing(dynamic profile, List<Word> words) {
    final now = DateTime.now();
    final todayCount = words.where((w) {
      if (w.reviewedAt == null) return false;
      final d = w.reviewedAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
    final target = profile.dailyTarget;
    final double progress = target > 0 ? (todayCount / target).clamp(0.0, 1.0) : 0.0;
    
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: progress == 0 ? 0.005 : progress,
              strokeWidth: 3, // Very thin stroke
              backgroundColor: const Color(0xFF1A1A1A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE10600)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$todayCount',
                style: GoogleFonts.outfit(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                  letterSpacing: -2.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '/ $target',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Minimal Stats Line ──
  Widget _buildMinimalStatsLine(dynamic profile, int masteredCount) {
    final int streak = profile.streakDays is int ? profile.streakDays : 0;
    return Text(
      '🔥 $streak日  •  $masteredCount語 習得済',
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: Colors.white.withOpacity(0.5),
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Full-bleed Session Band ──
  Widget _buildSessionBand(BuildContext context, int totalWordsCount, dynamic profile) {
    final interest = profile.interests.isNotEmpty ? profile.interests.first : '';
    final hasKey = profile.apiKey.isNotEmpty;
    final subText = hasKey && interest.isNotEmpty
        ? 'あなたの興味（$interest）に基づいた例文で学習を開始'
        : '暗記カードで学習を開始';

    return Material(
      color: const Color(0xFFE10600), // Deep red, no padding around it, no radius
      child: InkWell(
        onTap: () {
          _startLearning(
            context,
            totalWordsCount,
            isTest: false,
            isSpelling: false,
            screenBuilder: (config) => CardLearningScreen(config: config),
          );
        },
        child: Container(
          width: double.infinity,
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SESSION',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasKey)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(
                    'モック動作中',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mode List (Card-less) ──
  Widget _buildModeList(BuildContext context, int totalWordsCount) {
    return Column(
      children: [
        _buildListDivider(),
        _buildListItem(
          icon: Icons.speed_rounded,
          title: 'QUIZ',
          subtitle: '4択テストで瞬発力を測定',
          onTap: () => _startLearning(
            context, totalWordsCount,
            isTest: true, isSpelling: false,
            screenBuilder: (config) => QuizTestScreen(config: config),
          ),
        ),
        _buildListDivider(),
        _buildListItem(
          icon: Icons.edit_rounded,
          title: 'SPELL',
          subtitle: 'スペルテストで正確性を強化',
          onTap: () => _startLearning(
            context, totalWordsCount,
            isTest: true, isSpelling: true,
            screenBuilder: (config) => SpellingTestScreen(config: config),
          ),
        ),
        _buildListDivider(),
        _buildListItem(
          icon: Icons.headset_mic_rounded,
          title: 'RADIO',
          subtitle: 'AIが自動で無線会話に組み込み',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ChatTestScreen()),
          ),
        ),
        _buildListDivider(),
      ],
    );
  }

  Widget _buildListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white.withOpacity(0.4)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.05), // Hairline dark grey
    );
  }

  // ── Footer ──
  Widget _buildFooter(int masteredCount, int totalCount) {
    final percent = totalCount > 0 ? (masteredCount / totalCount * 100).toStringAsFixed(1) : '0';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$masteredCount / $totalCount語 ($percent%)',
          style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3), fontSize: 10),
        ),
        Text(
          'v4.0',
          style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3), fontSize: 10),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LEARNING CONFIG BOTTOM SHEET (Minimal version)
// ═══════════════════════════════════════════════════════════
class _LearningConfigBottomSheet extends StatefulWidget {
  final bool isTest;
  final bool isSpelling;
  final int totalWordsCount;

  const _LearningConfigBottomSheet({
    required this.isTest,
    required this.isSpelling,
    required this.totalWordsCount,
  });

  @override
  State<_LearningConfigBottomSheet> createState() => _LearningConfigBottomSheetState();
}

class _LearningConfigBottomSheetState extends State<_LearningConfigBottomSheet> {
  late LanguageDirection _direction;
  RangeType _rangeType = RangeType.all;
  OrderType _orderType = OrderType.random;
  int _questionCount = 10;
  
  final TextEditingController _startIdController = TextEditingController(text: '1');
  final TextEditingController _endIdController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _direction = widget.isSpelling ? LanguageDirection.jaToEn : LanguageDirection.enToJa;
  }

  @override
  void dispose() {
    _startIdController.dispose();
    _endIdController.dispose();
    super.dispose();
  }

  void _selectQuickRange(int start, int end) {
    setState(() {
      _rangeType = RangeType.customRange;
      _startIdController.text = start.toString();
      _endIdController.text = end.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    // A clean, minimal bottom sheet without heavy borders
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414), // Dark surface
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)), // Sharp edges or minimal radius. Let's use 0 for brutalism, or very small.
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CONFIGURATION',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 32),

            if (!widget.isSpelling) ...[
              _buildSectionTitle('DIRECTION'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildChoiceItem('EN → JP', _direction == LanguageDirection.enToJa, () => setState(() => _direction = LanguageDirection.enToJa))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildChoiceItem('JP → EN', _direction == LanguageDirection.jaToEn, () => setState(() => _direction = LanguageDirection.jaToEn))),
                ],
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionTitle('SCOPE'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('ALL', RangeType.all),
                _buildFilterChip('STAR', RangeType.favorites),
                _buildFilterChip('NEW', RangeType.unlearned),
                _buildFilterChip('WEAK', RangeType.weak),
                _buildFilterChip('MASTERED', RangeType.mastered),
                _buildFilterChip('CUSTOM', RangeType.customRange),
              ],
            ),
            const SizedBox(height: 12),

            if (_rangeType == RangeType.customRange) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startIdController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('START ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endIdController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      decoration: _inputDecoration('END ID'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickRangeButton(1, 100),
                    _buildQuickRangeButton(101, 200),
                    _buildQuickRangeButton(201, 300),
                    _buildQuickRangeButton(301, 400),
                    _buildQuickRangeButton(401, 500),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 16),
            ],

            _buildSectionTitle('ORDER'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildChoiceItem('RANDOM', _orderType == OrderType.random, () => setState(() => _orderType = OrderType.random))),
                const SizedBox(width: 12),
                Expanded(child: _buildChoiceItem('ID', _orderType == OrderType.idOrder, () => setState(() => _orderType = OrderType.idOrder))),
                const SizedBox(width: 12),
                Expanded(child: _buildChoiceItem('A-Z', _orderType == OrderType.alphabetical, () => setState(() => _orderType = OrderType.alphabetical))),
              ],
            ),
            const SizedBox(height: 24),

            if (widget.isTest) ...[
              _buildSectionTitle('QUESTIONS'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildChoiceItem('10', _questionCount == 10, () => setState(() => _questionCount = 10))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildChoiceItem('20', _questionCount == 20, () => setState(() => _questionCount = 20))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildChoiceItem('30', _questionCount == 30, () => setState(() => _questionCount = 30))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildChoiceItem('ALL', _questionCount == 9999, () => setState(() => _questionCount = 9999))),
                ],
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  int startId = int.tryParse(_startIdController.text) ?? 1;
                  int endId = int.tryParse(_endIdController.text) ?? 100;
                  if (startId < 1) startId = 1;
                  if (endId < startId) endId = startId + 10;

                  Navigator.pop(context, LearningConfig(
                    direction: _direction,
                    rangeType: _rangeType,
                    orderType: _orderType,
                    startId: startId,
                    endId: endId,
                    questionCount: _questionCount,
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE10600),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Sharp edges
                ),
                child: Text(
                  'BEGIN',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.3),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildChoiceItem(String title, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFFE10600) : Colors.white.withOpacity(0.1),
              width: 2,
            ),
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Colors.white : Colors.white.withOpacity(0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RangeType type) {
    final selected = _rangeType == type;
    return InkWell(
      onTap: () => setState(() => _rangeType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: selected ? Colors.white : Colors.white.withOpacity(0.5),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRangeButton(int start, int end) {
    return InkWell(
      onTap: () => _selectQuickRange(start, end),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          '$start-$end',
          style: GoogleFonts.outfit(fontSize: 10, color: Colors.white.withOpacity(0.5)),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1.0),
      filled: true,
      fillColor: Colors.black,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE10600))),
    );
  }
}
