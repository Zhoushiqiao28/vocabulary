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

  // Start daily session pre-configured with DUE words
  void _startDueReview(BuildContext context, int totalWords) {
    final config = LearningConfig(
      direction: LanguageDirection.enToJa,
      rangeType: RangeType.due,
      orderType: OrderType.random,
      questionCount: 9999, // Review all due words
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CardLearningScreen(config: config)),
    );
  }

  // Open custom learning configuration
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
    // Count reviewed today
    final todayReviewedCount = words.where((w) {
      if (w.reviewedAt == null) return false;
      final d = w.reviewedAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    // Count due words (unlearned OR nextReviewAt <= now)
    final dueWords = words.where((w) {
      return w.nextReviewAt == null || w.nextReviewAt!.isBefore(now);
    }).toList();

    // Stats
    final masteredCount = words.where((w) => w.status == 1).length;
    final weakCount = words.where((w) => w.status == 2).length;
    final unlearnedCount = words.where((w) => w.status == 0).length;

    // Past 7 Days Sparkline Data
    final List<double> chartData = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return words.where((w) {
        if (w.reviewedAt == null) return false;
        final d = w.reviewedAt!;
        return d.year == day.year && d.month == day.month && d.day == day.day;
      }).length.toDouble();
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
    List<double> chartData,
  ) {
    return Column(
      children: [
        // Mobile Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'vocaba',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Row(
                children: [
                  _buildStreakChip(profile.streakDays),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // Scrollable Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            children: [
              _buildGreeting(profile.name, dueCount),
              const SizedBox(height: 16),
              _buildSessionControlPanel(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
              const SizedBox(height: 24),
              
              _buildSectionHeader('Weekly Activity'),
              const SizedBox(height: 8),
              SizedBox(height: 60, child: _buildSparklineCard(chartData)),
              const SizedBox(height: 24),

              _buildSectionHeader('Curriculum'),
              const SizedBox(height: 8),
              _buildModesPanel(context, words.length),
              const SizedBox(height: 24),

              _buildSectionHeader('Vocabulary Status'),
              const SizedBox(height: 8),
              _buildStatsRow(mastered, weak, unlearned),
              const SizedBox(height: 24),

              _buildSectionHeader('Recently Reviewed'),
              const SizedBox(height: 8),
              _buildRecentWordsTable(context, words),
              const SizedBox(height: 32),
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
    List<double> chartData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Persistent Sidebar (Width: 260px)
        Container(
          width: 250,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: AppTheme.borderColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vocaba',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 24),
              
              // Sidebar Navigation items
              _buildSidebarItem(context, Icons.dashboard_outlined, 'Dashboard', null),
              _buildSidebarItem(context, Icons.menu_book_rounded, 'Word Library', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WordListScreen()));
              }),
              _buildSidebarItem(context, Icons.headset_mic_rounded, 'AI Radio Chat', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChatTestScreen()));
              }),
              _buildSidebarItem(context, Icons.settings_rounded, 'Settings', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),
              
              const Spacer(),
              
              // Weekly Sparkline In Sidebar
              Text(
                'WEEKLY ACTIVITY',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 60, child: _buildSparklineCard(chartData)),
              const SizedBox(height: 24),

              // Calendar Heatmap trigger
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const LearningCalendarDialog(),
                  );
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 12),
                label: const Text('Learning Calendar', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 32),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
              const SizedBox(height: 24),

              // Profile / Streak at bottom
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.interests.isNotEmpty ? profile.interests.first : 'Vocabulary Builder',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStreakChip(profile.streakDays),
                ],
              )
            ],
          ),
        ),

        // Right Column: Main Workspace Panel
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGreeting(profile.name, dueCount),
                const SizedBox(height: 24),

                // Main Session CTA Banner
                _buildSessionControlPanel(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
                const SizedBox(height: 28),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left partition: Curriculum & Stats
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Curriculum Modes'),
                          const SizedBox(height: 10),
                          _buildModesPanel(context, words.length),
                          const SizedBox(height: 24),
                          
                          _buildSectionHeader('Vocabulary Status'),
                          const SizedBox(height: 10),
                          _buildStatsRow(mastered, weak, unlearned),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right partition: Recently Reviewed list
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Recently Reviewed'),
                          const SizedBox(height: 10),
                          _buildRecentWordsTable(context, words),
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
  // REUSABLE SUB-WIDGETS
  // ═══════════════════════════════════════════════

  Widget _buildGreeting(String name, int dueCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $name.',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          dueCount > 0
              ? 'You have $dueCount words scheduled for review under Spaced Repetition.'
              : 'All scheduled words have been reviewed. Ready to learn more?',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Streak Badge
  Widget _buildStreakChip(int streakDays) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
      ),
      child: Text(
        '${streakDays}d streak',
        style: const TextStyle(
          color: AppTheme.warning,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Sidebar navigation item
  Widget _buildSidebarItem(BuildContext context, IconData icon, String title, VoidCallback? onTap) {
    final active = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: active
                ? BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? AppTheme.primary : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Core CTA Session Panel
  Widget _buildSessionControlPanel(
    BuildContext context,
    int dueCount,
    int todayReviewed,
    int dailyTarget,
    int totalWords,
  ) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: AppTheme.cardDecoration(withShadow: false),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY SESSION',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$todayReviewed / $dailyTarget reviewed today',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Target progress indicator. $dueCount words remaining due.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                // Linear Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: dailyTarget > 0 ? (todayReviewed / dailyTarget).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: const Color(0xFF2E2E33),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 24),
          ElevatedButton(
            onPressed: () => _startDueReview(context, totalWords),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 42),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(dueCount > 0 ? 'Review $dueCount' : 'Start Review'),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  // Sparkline chart card
  Widget _buildSparklineCard(List<double> data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: AppTheme.cardDecoration(),
      child: CustomPaint(
        painter: SparklinePainter(data),
        child: Container(),
      ),
    );
  }

  // Stats Counters
  Widget _buildStatsRow(int mastered, int weak, int unlearned) {
    return Row(
      children: [
        Expanded(child: _buildStatCell('MASTERED', mastered, AppTheme.success)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCell('WEAK', weak, AppTheme.error)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCell('UNLEARNED', unlearned, AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildStatCell(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          )
        ],
      ),
    );
  }

  // Menu items for Quiz, Spelling, Radio
  Widget _buildModesPanel(BuildContext context, int totalWords) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          _buildModeRow(
            context,
            '01 / QUIZ',
            'Multiple choice retention test',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: false,
              screenBuilder: (config) => QuizTestScreen(config: config),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _buildModeRow(
            context,
            '02 / SPELLING',
            'Active dictation writing assessment',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: true,
              screenBuilder: (config) => SpellingTestScreen(config: config),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _buildModeRow(
            context,
            '03 / RADIO CHAT',
            'Interactive simulated AI conversation',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ChatTestScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeRow(BuildContext context, String code, String desc, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppTheme.textMuted,
            )
          ],
        ),
      ),
    );
  }

  // Recently Reviewed Data Table
  Widget _buildRecentWordsTable(BuildContext context, List<Word> words) {
    final now = DateTime.now();
    // Sort words by reviewedAt desc, taking only the ones actually reviewed
    final reviewedWords = words
        .where((w) => w.reviewedAt != null)
        .toList();
    reviewedWords.sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));
    
    final recent = reviewedWords.take(7).toList();

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: recent.isEmpty
          ? const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  'No reviews recorded yet today.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            )
          : Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  color: AppTheme.background.withOpacity(0.5),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'WORD',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'MEANING',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'STATUS',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'NEXT',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Table rows
                ...recent.map((word) {
                  final due = word.nextReviewAt == null || word.nextReviewAt!.isBefore(now);
                  String nextText = 'Due';
                  Color nextColor = AppTheme.warning;

                  if (!due && word.nextReviewAt != null) {
                    final diff = word.nextReviewAt!.difference(now).inDays;
                    if (diff <= 0) {
                      nextText = 'Tomorrow';
                      nextColor = AppTheme.textSecondary;
                    } else {
                      nextText = 'in ${diff + 1}d';
                      nextColor = AppTheme.textSecondary;
                    }
                  }

                  Color statusColor = AppTheme.textSecondary;
                  String statusText = 'New';
                  if (word.status == 1) {
                    statusColor = AppTheme.success;
                    statusText = 'Mastered';
                  } else if (word.status == 2) {
                    statusColor = AppTheme.error;
                    statusText = 'Weak';
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            word.spelling,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            word.meaningJa,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            nextText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: nextColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

// ── Custom Sparkline Painter ──
class SparklinePainter extends CustomPainter {
  final List<double> data;
  SparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double maxVal = data.reduce(max);
    final double minVal = data.reduce(min);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      // Invert Y axis
      final double y = size.height - ((data[i] - minVal) / range * (size.height - 12) + 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw point nodes
    final dotPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    final dotOuterPaint = Paint()
      ..color = AppTheme.surface
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = size.height - ((data[i] - minVal) / range * (size.height - 12) + 6);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      canvas.drawCircle(Offset(x, y), 1.5, dotOuterPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
// LEARNING CONFIG BOTTOM SHEET
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
  RangeType _rangeType = RangeType.due; // Due by default under SM2
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
      decoration: const BoxDecoration(
        color: AppTheme.elevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CONFIGURATION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),

            if (!widget.isSpelling) ...[
              _buildSectionTitle('DIRECTION'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildChoiceItem('EN → JP', _direction == LanguageDirection.enToJa, () => setState(() => _direction = LanguageDirection.enToJa))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildChoiceItem('JP → EN', _direction == LanguageDirection.jaToEn, () => setState(() => _direction = LanguageDirection.jaToEn))),
                ],
              ),
              const SizedBox(height: 20),
            ],

            _buildSectionTitle('SCOPE'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterChip('DUE (復習対象)', RangeType.due),
                _buildFilterChip('ALL (全体)', RangeType.all),
                _buildFilterChip('STAR (星)', RangeType.favorites),
                _buildFilterChip('NEW (未学習)', RangeType.unlearned),
                _buildFilterChip('WEAK (苦手)', RangeType.weak),
                _buildFilterChip('MASTERED (習得)', RangeType.mastered),
                _buildFilterChip('CUSTOM (範囲)', RangeType.customRange),
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
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('START ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endIdController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('END ID'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 20),
            ] else ...[
              const SizedBox(height: 8),
            ],

            _buildSectionTitle('ORDER'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildChoiceItem('RANDOM', _orderType == OrderType.random, () => setState(() => _orderType = OrderType.random))),
                const SizedBox(width: 12),
                Expanded(child: _buildChoiceItem('ID', _orderType == OrderType.idOrder, () => setState(() => _orderType = OrderType.idOrder))),
                const SizedBox(width: 12),
                Expanded(child: _buildChoiceItem('A-Z', _orderType == OrderType.alphabetical, () => setState(() => _orderType = OrderType.alphabetical))),
              ],
            ),
            const SizedBox(height: 20),

            if (widget.isTest) ...[
              _buildSectionTitle('QUESTIONS'),
              const SizedBox(height: 8),
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
              const SizedBox(height: 28),
            ],

            ElevatedButton(
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
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('BEGIN'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildChoiceItem(String title, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
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
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRangeButton(int start, int end) {
    return InkWell(
      onTap: () => _selectQuickRange(start, end),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          '$start-$end',
          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
      filled: true,
      fillColor: AppTheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), borderSide: const BorderSide(color: AppTheme.borderColor)),
    );
  }
}
