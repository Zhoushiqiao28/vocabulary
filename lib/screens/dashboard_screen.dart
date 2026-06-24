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

  void _startDueReview(BuildContext context, int totalWords) {
    final config = LearningConfig(
      direction: LanguageDirection.enToJa,
      rangeType: RangeType.due,
      orderType: OrderType.random,
      questionCount: 9999,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CardLearningScreen(config: config)),
    );
  }

  void _startLearningConfig(
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

    final now = DateTime.now();
    final todayReviewedCount = words.where((w) {
      if (w.reviewedAt == null) return false;
      final d = w.reviewedAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final dueWords = words.where((w) {
      return w.nextReviewAt == null || w.nextReviewAt!.isBefore(now);
    }).toList();

    final masteredCount = words.where((w) => w.status == 1).length;
    final weakCount = words.where((w) => w.status == 2).length;
    final unlearnedCount = words.where((w) => w.status == 0).length;

    // Past 7 days activity data
    final List<int> chartData = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return words.where((w) {
        if (w.reviewedAt == null) return false;
        final d = w.reviewedAt!;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length;
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: isWide
            ? _buildWideLayout(context, profile, words, todayReviewedCount, dueWords.length, masteredCount, weakCount, unlearnedCount, chartData)
            : _buildNarrowLayout(context, profile, words, todayReviewedCount, dueWords.length, masteredCount, weakCount, unlearnedCount, chartData),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // NARROW LAYOUT (Mobile < 800px)
  // ═══════════════════════════════════════════════
  Widget _buildNarrowLayout(
    BuildContext context,
    UserProfile profile,
    List<Word> words,
    int todayReviewed,
    int dueCount,
    int mastered,
    int weak,
    int unlearned,
    List<int> chartData,
  ) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VocaBA',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  if (profile.streakDays > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                      ),
                      child: Text(
                        '${profile.streakDays}日連続',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16),
            children: [
              // Today's Mission Card
              _buildMissionCard(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
              const SizedBox(height: AppTheme.sp24),

              // Activity Chart
              _buildSectionLabel('今週のアクティビティ'),
              const SizedBox(height: AppTheme.sp8),
              _buildActivityChart(chartData),
              const SizedBox(height: AppTheme.sp24),

              // Stats Row
              _buildStatsRow(mastered, weak, unlearned, words.length),
              const SizedBox(height: AppTheme.sp24),

              // Learning Modes
              _buildSectionLabel('学習モード'),
              const SizedBox(height: AppTheme.sp8),
              _buildModesPanel(context, words.length),
              const SizedBox(height: AppTheme.sp24),

              // Recent Words
              _buildSectionLabel('最近の学習'),
              const SizedBox(height: AppTheme.sp8),
              _buildRecentWords(context, words),
              const SizedBox(height: AppTheme.sp32),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // WIDE LAYOUT (Desktop ≥ 800px)
  // ═══════════════════════════════════════════════
  Widget _buildWideLayout(
    BuildContext context,
    UserProfile profile,
    List<Word> words,
    int todayReviewed,
    int dueCount,
    int mastered,
    int weak,
    int unlearned,
    List<int> chartData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sidebar
        Container(
          width: 220,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              right: BorderSide(color: AppTheme.borderColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.all(AppTheme.sp20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VocaBA',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.sp32),

              _buildSidebarItem(context, Icons.dashboard_outlined, 'ダッシュボード', null),
              _buildSidebarItem(context, Icons.menu_book_outlined, '単語ライブラリ', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WordListScreen()));
              }),
              _buildSidebarItem(context, Icons.chat_bubble_outline_rounded, 'AIチャット', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChatTestScreen()));
              }),
              _buildSidebarItem(context, Icons.settings_outlined, '設定', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),

              const Spacer(),

              // Activity chart in sidebar
              _buildSectionLabel('今週のアクティビティ'),
              const SizedBox(height: AppTheme.sp8),
              _buildActivityChart(chartData),
              const SizedBox(height: AppTheme.sp16),

              // Calendar trigger
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const LearningCalendarDialog(),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 14),
                  label: Text('カレンダー', style: GoogleFonts.outfit(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sp16),

              // Profile chip
              Container(
                padding: const EdgeInsets.all(AppTheme.sp12),
                decoration: AppTheme.cardDecoration(),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.15),
                      ),
                      child: Center(
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'U',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (profile.streakDays > 0)
                            Text(
                              '${profile.streakDays}日連続',
                              style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.warning),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.sp24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Greeting
                Text(
                  'おかえりなさい、${profile.name}さん',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.sp4),
                Text(
                  dueCount > 0
                      ? '復習対象の単語が $dueCount 語あります'
                      : '今日の復習は完了しています 🎉',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: dueCount > 0 ? AppTheme.warning : AppTheme.success,
                  ),
                ),
                const SizedBox(height: AppTheme.sp24),

                // Mission Card
                _buildMissionCard(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
                const SizedBox(height: AppTheme.sp24),

                // Two columns: Modes + Stats | Recent words
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsRow(mastered, weak, unlearned, words.length),
                          const SizedBox(height: AppTheme.sp24),
                          _buildSectionLabel('学習モード'),
                          const SizedBox(height: AppTheme.sp8),
                          _buildModesPanel(context, words.length),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.sp24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('最近の学習'),
                          const SizedBox(height: AppTheme.sp8),
                          _buildRecentWords(context, words),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ═══════════════════════════════════════════════

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, IconData icon, String title, VoidCallback? onTap) {
    final active = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Today's Mission Card ───
  Widget _buildMissionCard(BuildContext context, int dueCount, int todayReviewed, int dailyTarget, int totalWords) {
    final missionTotal = dueCount + (dailyTarget > dueCount ? dailyTarget - dueCount : 0);
    final progress = dailyTarget > 0 ? (todayReviewed / dailyTarget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.sp20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Mission",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(fontSize: 15, color: AppTheme.textPrimary),
                        children: [
                          if (dueCount > 0) ...[
                            TextSpan(
                              text: '復習 ${dueCount}語',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const TextSpan(text: ' が待っています'),
                          ] else
                            const TextSpan(
                              text: '復習完了！新しい単語に挑戦しよう',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp12),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: AppTheme.elevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? AppTheme.success : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.sp4),
                    Text(
                      '$todayReviewed / $dailyTarget 完了',
                      style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.sp16),
              // Start button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _startDueReview(context, totalWords),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dueCount > 0 ? AppTheme.primary : AppTheme.elevated,
                    foregroundColor: dueCount > 0 ? Colors.white : AppTheme.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: dueCount > 0 ? BorderSide.none : const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                  child: Text(
                    dueCount > 0 ? '開始 →' : '学習する',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Activity Chart (Simple bar chart) ───
  Widget _buildActivityChart(List<int> data) {
    final maxVal = data.reduce(max).toDouble();
    final range = maxVal == 0 ? 1.0 : maxVal;
    final days = ['月', '火', '水', '木', '金', '土', '日'];
    final now = DateTime.now();

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp8, vertical: AppTheme.sp8),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final ratio = data[i] / range;
          final dayIndex = (now.subtract(Duration(days: 6 - i)).weekday - 1) % 7;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (data[i] > 0)
                    Text(
                      '${data[i]}',
                      style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: data[i] > 0 ? ratio.clamp(0.08, 1.0) : 0.04,
                      child: Container(
                        decoration: BoxDecoration(
                          color: data[i] > 0
                              ? AppTheme.primary.withOpacity(0.6 + ratio * 0.4)
                              : AppTheme.elevated,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    days[dayIndex],
                    style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Stats Row ───
  Widget _buildStatsRow(int mastered, int weak, int unlearned, int total) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('習得', mastered, AppTheme.success)),
        const SizedBox(width: AppTheme.sp8),
        Expanded(child: _buildStatCard('苦手', weak, AppTheme.error)),
        const SizedBox(width: AppTheme.sp8),
        Expanded(child: _buildStatCard('未学習', unlearned, AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            count.toString(),
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Learning Modes ───
  Widget _buildModesPanel(BuildContext context, int totalWords) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          _buildModeRow(
            context,
            Icons.style_outlined,
            'フラッシュカード',
            '暗記カードで効率的に学習',
            () => _startLearningConfig(
              context, totalWords,
              isTest: false, isSpelling: false,
              screenBuilder: (config) => CardLearningScreen(config: config),
            ),
          ),
          const Divider(height: 1),
          _buildModeRow(
            context,
            Icons.quiz_outlined,
            '選択肢クイズ',
            '4択問題で記憶をテスト',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: false,
              screenBuilder: (config) => QuizTestScreen(config: config),
            ),
          ),
          const Divider(height: 1),
          _buildModeRow(
            context,
            Icons.edit_outlined,
            'スペリング',
            'タイピングで綴りを確認',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: true,
              screenBuilder: (config) => SpellingTestScreen(config: config),
            ),
          ),
          const Divider(height: 1),
          _buildModeRow(
            context,
            Icons.chat_bubble_outline_rounded,
            'AIチャット',
            '会話の中で単語を使う練習',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ChatTestScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeRow(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ─── Recent Words ───
  Widget _buildRecentWords(BuildContext context, List<Word> words) {
    final now = DateTime.now();
    final reviewedWords = words.where((w) => w.reviewedAt != null).toList();
    reviewedWords.sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));
    final recent = reviewedWords.take(8).toList();

    if (recent.isEmpty) {
      return Container(
        height: 120,
        decoration: AppTheme.cardDecoration(),
        child: Center(
          child: Text(
            'まだ学習記録がありません',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: recent.map((word) {
          final statusColor = AppTheme.statusColor(word.status);
          final statusLabel = AppTheme.statusLabel(word.status);

          // Next review date
          String nextReview = '未設定';
          if (word.nextReviewAt != null) {
            if (word.nextReviewAt!.isBefore(now)) {
              nextReview = '復習対象';
            } else {
              final diff = word.nextReviewAt!.difference(now).inDays;
              if (diff == 0) {
                nextReview = '今日';
              } else if (diff <= 7) {
                nextReview = '${diff}日後';
              } else {
                nextReview = '${word.nextReviewAt!.month}/${word.nextReviewAt!.day}';
              }
            }
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.spelling,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        word.meaningJa,
                        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: AppTheme.statusChipDecoration(color: statusColor, filled: true),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor),
                  ),
                ),
                const SizedBox(width: AppTheme.sp12),
                // Next review
                SizedBox(
                  width: 60,
                  child: Text(
                    nextReview,
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LEARNING CONFIG BOTTOM SHEET (v7.0 clean design)
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
  RangeType _rangeType = RangeType.due;
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.sp20,
        right: AppTheme.sp20,
        top: AppTheme.sp20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.sp24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            Text(
              '学習設定',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.sp20),

            if (!widget.isSpelling) ...[
              _buildSectionTitle('出題方向'),
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Expanded(child: _buildChoiceItem('英語 → 日本語', _direction == LanguageDirection.enToJa, () => setState(() => _direction = LanguageDirection.enToJa))),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(child: _buildChoiceItem('日本語 → 英語', _direction == LanguageDirection.jaToEn, () => setState(() => _direction = LanguageDirection.jaToEn))),
                ],
              ),
              const SizedBox(height: AppTheme.sp20),
            ],

            _buildSectionTitle('出題範囲'),
            const SizedBox(height: AppTheme.sp8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterChip('復習対象', RangeType.due),
                _buildFilterChip('すべて', RangeType.all),
                _buildFilterChip('お気に入り', RangeType.favorites),
                _buildFilterChip('未学習', RangeType.unlearned),
                _buildFilterChip('苦手', RangeType.weak),
                _buildFilterChip('習得済み', RangeType.mastered),
                _buildFilterChip('範囲指定', RangeType.customRange),
              ],
            ),
            const SizedBox(height: AppTheme.sp12),

            if (_rangeType == RangeType.customRange) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startIdController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '開始ID',
                        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.sp12),
                  Expanded(
                    child: TextField(
                      controller: _endIdController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: '終了ID',
                        labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.sp8),
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
              const SizedBox(height: AppTheme.sp16),
            ],

            _buildSectionTitle('並び順'),
            const SizedBox(height: AppTheme.sp8),
            Row(
              children: [
                Expanded(child: _buildChoiceItem('ランダム', _orderType == OrderType.random, () => setState(() => _orderType = OrderType.random))),
                const SizedBox(width: AppTheme.sp8),
                Expanded(child: _buildChoiceItem('ID順', _orderType == OrderType.idOrder, () => setState(() => _orderType = OrderType.idOrder))),
                const SizedBox(width: AppTheme.sp8),
                Expanded(child: _buildChoiceItem('A-Z', _orderType == OrderType.alphabetical, () => setState(() => _orderType = OrderType.alphabetical))),
              ],
            ),
            const SizedBox(height: AppTheme.sp20),

            if (widget.isTest) ...[
              _buildSectionTitle('問題数'),
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Expanded(child: _buildChoiceItem('10', _questionCount == 10, () => setState(() => _questionCount = 10))),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(child: _buildChoiceItem('20', _questionCount == 20, () => setState(() => _questionCount = 20))),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(child: _buildChoiceItem('30', _questionCount == 30, () => setState(() => _questionCount = 30))),
                  const SizedBox(width: AppTheme.sp8),
                  Expanded(child: _buildChoiceItem('全部', _questionCount == 9999, () => setState(() => _questionCount = 9999))),
                ],
              ),
              const SizedBox(height: AppTheme.sp24),
            ],

            SizedBox(
              height: 52,
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Text(
                  'セッション開始',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
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
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildChoiceItem(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.primary.withOpacity(0.4) : AppTheme.borderColor,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RangeType type) {
    final selected = _rangeType == type;
    return GestureDetector(
      onTap: () => setState(() => _rangeType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.primary.withOpacity(0.4) : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRangeButton(int start, int end) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _selectQuickRange(start, end),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Text(
            '$start-$end',
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
