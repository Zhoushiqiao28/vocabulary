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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                _buildHeader(context, profile),
                const SizedBox(height: 16),

                // Motivating Status Panel (Daily Target Progress & Level XP)
                _buildStatusAndGoalsPanel(context, profile, words),
                const SizedBox(height: 16),

                // Compact AI Message Banner
                _buildAIMessageBanner(profile),
                const SizedBox(height: 20),

                // HUGE main start card (with fixed height for scrollview stability)
                SizedBox(
                  height: 160,
                  child: _buildMainStartCard(context, words.length),
                ),
                const SizedBox(height: 20),

                // Practice modes
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubActionCard(
                            context: context,
                            title: '4択テスト',
                            icon: Icons.quiz_rounded,
                            color: AppTheme.secondary,
                            onTap: () {
                              _startLearning(
                                context,
                                words.length,
                                isTest: true,
                                isSpelling: false,
                                screenBuilder: (config) => QuizTestScreen(config: config),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSubActionCard(
                            context: context,
                            title: 'スペルテスト',
                            icon: Icons.keyboard_rounded,
                            color: AppTheme.accent,
                            onTap: () {
                              _startLearning(
                                context,
                                words.length,
                                isTest: true,
                                isSpelling: true,
                                screenBuilder: (config) => SpellingTestScreen(config: config),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSubActionCard(
                      context: context,
                      title: 'AIチャット対話テスト',
                      description: '苦手な単語や今日の学習単語をAIが自動で会話に組み込み',
                      icon: Icons.chat_bubble_rounded,
                      color: AppTheme.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ChatTestScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom mini footer
                _buildMiniFooter(masteredCount, words.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAndGoalsPanel(BuildContext context, dynamic profile, List<Word> words) {
    // 1. 今日のレビュー数
    final now = DateTime.now();
    final todayReviewedCount = words.where((w) {
      if (w.reviewedAt == null) return false;
      final d = w.reviewedAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final target = profile.dailyTarget;
    final double goalProgress = target > 0 
        ? (todayReviewedCount / target).clamp(0.0, 1.0) 
        : 0.0;
    final bool isGoalAchieved = todayReviewedCount >= target;

    // 2. XP & レベル計算
    final reviewedWords = words.where((w) => w.reviewedAt != null).length;
    final masteredWords = words.where((w) => w.status == 1).length;
    final int streak = profile.streakDays is int ? profile.streakDays : 0;
    final int totalXp = (reviewedWords * 10) + (masteredWords * 20) + (streak * 50);
    
    final int level = (totalXp / 150).floor() + 1;
    final int xpInCurrentLevel = totalXp % 150;
    final double xpProgress = xpInCurrentLevel / 150.0;

    String title = 'Beginner';
    if (level >= 15) {
      title = 'Legend 👑';
    } else if (level >= 10) {
      title = 'Grandmaster 🌟';
    } else if (level >= 7) {
      title = 'Master';
    } else if (level >= 5) {
      title = 'Expert';
    } else if (level >= 3) {
      title = 'Challenger';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // 左側: 今日の目標プログレスリング
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return SweepGradient(
                      startAngle: 0.0,
                      endAngle: pi * 2,
                      colors: isGoalAchieved
                          ? [Colors.amber, Colors.orangeAccent, Colors.amber]
                          : [AppTheme.primary, Colors.blueAccent, AppTheme.primary],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(rect);
                  },
                  child: CircularProgressIndicator(
                    value: goalProgress == 0 ? 0.01 : goalProgress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGoalAchieved)
                    const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20)
                  else
                    Text(
                      '$todayReviewedCount',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  Text(
                    '/$target語',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(width: 20),
          
          // 右側: レベルとXPプログレス
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // レベルと称号
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.secondary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Lv. $level',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                
                // XPバー
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isGoalAchieved ? '目標達成！🎉' : '今日の学習進捗',
                      style: TextStyle(
                        fontSize: 10,
                        color: isGoalAchieved ? Colors.amber : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$xpInCurrentLevel / 150 XP',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile) {
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final dateString = "${now.year}年${now.month}月${now.day}日(${weekdays[now.weekday - 1]})";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${profile.name} 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const LearningCalendarDialog(),
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${profile.streakDays}日連続',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateString,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: AppTheme.textSecondary),
              tooltip: '単語帳リスト',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const WordListScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
              tooltip: '設定',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAIMessageBanner(dynamic profile) {
    final welcomeText = profile.apiKey.isEmpty
        ? '⚠️ 右上からGemini APIキーを設定してください。モックモードで動作中。'
        : '今日の暗記カードに「${profile.interests.first}」の例文を追加しました！さあ、始めましょう。';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.glassBoxDecoration(color: AppTheme.primary),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              welcomeText,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStartCard(BuildContext context, int totalWordsCount) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF5A189A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.style_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  '暗記カード学習を開始',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'タップして表裏をめくり、スワイプで覚えたか分類',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubActionCard({
    required BuildContext context,
    required String title,
    String? description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final bool hasDesc = description != null;
    return Container(
      height: hasDesc ? 76 : 110,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: hasDesc ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (hasDesc) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      ]
                    ],
                  ),
                ),
                if (hasDesc) const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniFooter(int masteredCount, int totalCount) {
    final percent = totalCount > 0 ? (masteredCount / totalCount * 100).toStringAsFixed(1) : '0';
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '📊 習得状況: $masteredCount / $totalCount 語 ($percent%)',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          Text(
            'VocaBA v2.7',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 10),
          )
        ],
      ),
    );
  }
}

// STYLISH LEARNING CONFIG BOTTOM SHEET
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
    // Spelling test is fixed to JP -> EN
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              '⚙️ 学習設定',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 1. Language Direction (Only if not spelling test)
            if (!widget.isSpelling) ...[
              _buildSectionTitle('出題の向き'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'EN ➡️ JP',
                      subtitle: '英語を見て日本語を思い出す',
                      selected: _direction == LanguageDirection.enToJa,
                      onTap: () => setState(() => _direction = LanguageDirection.enToJa),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'JP ➡️ EN',
                      subtitle: '日本語を見て英語を思い出す',
                      selected: _direction == LanguageDirection.jaToEn,
                      onTap: () => setState(() => _direction = LanguageDirection.jaToEn),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // 2. Range Filter
            _buildSectionTitle('出題範囲'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('全て', RangeType.all),
                _buildFilterChip('スターのみ ⭐', RangeType.favorites),
                _buildFilterChip('未学習のみ', RangeType.unlearned),
                _buildFilterChip('覚えてない ❌', RangeType.weak),
                _buildFilterChip('覚えた ⭕', RangeType.mastered),
                _buildFilterChip('ID範囲指定 🔢', RangeType.customRange),
              ],
            ),
            const SizedBox(height: 12),

            // Range Type Input / Presets
            if (_rangeType == RangeType.customRange) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startIdController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '開始 ID',
                              labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('〜', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _endIdController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: '終了 ID',
                              labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'クイック選択 (100語区切りプリセット)',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickRangeButton(1, 100),
                          _buildQuickRangeButton(101, 200),
                          _buildQuickRangeButton(201, 300),
                          _buildQuickRangeButton(301, 400),
                          _buildQuickRangeButton(401, 500),
                          _buildQuickRangeButton(501, 1000),
                          _buildQuickRangeButton(1001, widget.totalWordsCount),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              const SizedBox(height: 8),
            ],

            // 3. Order Type
            _buildSectionTitle('出題順'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOrderChip('ランダム', OrderType.random),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOrderChip('ID順', OrderType.idOrder),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOrderChip('アルファベット順', OrderType.alphabetical),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Question Count (If it is a test)
            if (widget.isTest) ...[
              _buildSectionTitle('出題数'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuestionCountChip('10問', 10),
                  const SizedBox(width: 8),
                  _buildQuestionCountChip('20問', 20),
                  const SizedBox(width: 8),
                  _buildQuestionCountChip('30問', 30),
                  const SizedBox(width: 8),
                  _buildQuestionCountChip('全問', 9999),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Start Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  int startId = int.tryParse(_startIdController.text) ?? 1;
                  int endId = int.tryParse(_endIdController.text) ?? 100;
                  
                  if (startId < 1) startId = 1;
                  if (endId < startId) endId = startId + 10;

                  final config = LearningConfig(
                    direction: _direction,
                    rangeType: _rangeType,
                    orderType: _orderType,
                    startId: startId,
                    endId: endId,
                    questionCount: _questionCount,
                  );
                  Navigator.pop(context, config);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  '学習を開始する',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RangeType type) {
    final selected = _rangeType == type;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _rangeType = type);
        }
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppTheme.primary : Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }

  Widget _buildQuickRangeButton(int start, int end) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: OutlinedButton(
        onPressed: () => _selectQuickRange(start, end),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          '$start-$end',
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildOrderChip(String label, OrderType type) {
    final selected = _orderType == type;
    return ChoiceChip(
      label: Container(
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _orderType = type);
        }
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppTheme.primary : Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }

  Widget _buildQuestionCountChip(String label, int count) {
    final selected = _questionCount == count;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _questionCount = count);
        }
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppTheme.primary : Colors.white.withOpacity(0.08),
        ),
      ),
    );
  }
}
