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
      questionCount: 9999, // Review all due words
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
    // Count reviewed today
    final todayReviewedCount = words.where((w) {
      if (w.reviewedAt == null) return false;
      final d = w.reviewedAt!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    // Count due words
    final dueWords = words.where((w) {
      return w.nextReviewAt == null || w.nextReviewAt!.isBefore(now);
    }).toList();

    // Stats
    final masteredCount = words.where((w) => w.status == 1).length;
    final weakCount = words.where((w) => w.status == 2).length;
    final unlearnedCount = words.where((w) => w.status == 0).length;

    // Past 7 Days Sparkline Data -> mapped to VFD values
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
        // Mobile Header with slit divider
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor, width: 1.0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VOCABA // CONSOLE_v6.0',
                style: GoogleFonts.shareTechMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.0,
                ),
              ),
              Row(
                children: [
                  _buildStreakLeds(profile.streakDays),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, size: 16, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildGreeting(profile.name, dueCount),
              const SizedBox(height: 16),
              _buildSessionControlPanel(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
              const SizedBox(height: 24),
              
              _buildSectionHeader('VFD SPECTRAM MONITOR (ACTIVITY)'),
              const SizedBox(height: 8),
              _buildSpectrumCard(chartData),
              const SizedBox(height: 24),

              _buildSectionHeader('SYSTEM CURRICULUM'),
              const SizedBox(height: 8),
              _buildModesPanel(context, words.length),
              const SizedBox(height: 24),

              _buildSectionHeader('VOCABULARY COUNTERS'),
              const SizedBox(height: 8),
              _buildStatsRow(mastered, weak, unlearned),
              const SizedBox(height: 24),

              _buildSectionHeader('SYSTEM MEASUREMENT LOG'),
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
    List<int> chartData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Physical Control Sidebar (Width: 260px)
        Container(
          width: 250,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              right: BorderSide(color: AppTheme.borderColor, width: 1.0),
            ),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VOCABA // CONSOLE_v6.0',
                style: GoogleFonts.shareTechMono(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Sidebar Navigation items (styled like toggle buttons)
              _buildSidebarItem(context, Icons.dashboard_outlined, 'DASHBOARD', null),
              _buildSidebarItem(context, Icons.menu_book_rounded, 'LIBRARY_LOG', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WordListScreen()));
              }),
              _buildSidebarItem(context, Icons.headset_mic_rounded, 'RADIO_CHAT', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChatTestScreen()));
              }),
              _buildSidebarItem(context, Icons.settings_rounded, 'SETTINGS', () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),
              
              const Spacer(),
              
              // VFD Sparkline In Sidebar
              Text(
                'VFD ACTIVITY SPECTRUM',
                style: GoogleFonts.shareTechMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildSpectrumCard(chartData),
              const SizedBox(height: 16),

              // Calendar Heatmap trigger (styled like a physical chassis socket button)
              TactileButton(
                height: 34,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const LearningCalendarDialog(),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'MATRIX LED CALENDAR',
                      style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Profile / Streak at bottom
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: AppTheme.displayBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'USER: ${profile.name.toUpperCase()}',
                      style: GoogleFonts.shareTechMono(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _buildStreakLeds(profile.streakDays),
                  ],
                ),
              )
            ],
          ),
        ),

        // Right Column: Main Workspace Panel
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGreeting(profile.name, dueCount),
                const SizedBox(height: 20),

                // Main Session CTA Banner
                _buildSessionControlPanel(context, dueCount, todayReviewed, profile.dailyTarget, words.length),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left partition: Curriculum & Stats
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('SYSTEM CURRICULUM'),
                          const SizedBox(height: 8),
                          _buildModesPanel(context, words.length),
                          const SizedBox(height: 24),
                          
                          _buildSectionHeader('VOCABULARY STATUS'),
                          const SizedBox(height: 8),
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
                          _buildSectionHeader('SYSTEM MEASUREMENT LOG'),
                          const SizedBox(height: 8),
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
          'WELCOME BACK, ${name.toUpperCase()}.',
          style: GoogleFonts.shareTechMono(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dueCount > 0
              ? 'WARNING: $dueCount WORDS ARE CURRENTLY DUE FOR REVIEW.'
              : 'SYSTEM STATUS: ALL SCHEDULED REVIEWS RECONCILED. NO OUTSTANDING DEBTS.',
          style: GoogleFonts.shareTechMono(
            color: dueCount > 0 ? AppTheme.warning : AppTheme.success,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // Hardware LED Streak indicator
  Widget _buildStreakLeds(int streakDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(7, (i) {
            final isLit = i < streakDays;
            return Container(
              margin: const EdgeInsets.only(right: 4.0),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLit ? AppTheme.warning : AppTheme.warning.withOpacity(0.12),
                boxShadow: isLit
                    ? [
                        BoxShadow(
                          color: AppTheme.warning.withOpacity(0.5),
                          blurRadius: 3,
                          spreadRadius: 0.5,
                        )
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'STREAK: $streakDays DAYS ACTIVE',
          style: GoogleFonts.shareTechMono(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        )
      ],
    );
  }

  // Sidebar navigation item
  Widget _buildSidebarItem(BuildContext context, IconData icon, String title, VoidCallback? onTap) {
    final active = onTap == null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: TactileButton(
        height: 38,
        onPressed: active ? null : onTap,
        color: active ? AppTheme.hover : AppTheme.surface,
        ledColor: AppTheme.primary,
        isLedOn: active,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              icon,
              size: 14,
              color: active ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            )
          ],
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
    final progress = dailyTarget > 0 ? (todayReviewed / dailyTarget).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY SESSION MODULE',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LOG: $todayReviewed / $dailyTarget REVIEWS COMPLETED TODAY',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STATUS: $dueCount DUE WORDS REMAINING IN QUEUE.',
                  style: GoogleFonts.shareTechMono(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 12),
                
                // LED segments styled progress indicator
                Row(
                  children: List.generate(20, (i) {
                    final isLit = (i / 20.0) < progress;
                    return Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.only(right: 2.0),
                        decoration: BoxDecoration(
                          color: isLit ? AppTheme.primary : AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(1.0),
                          boxShadow: isLit
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withOpacity(0.4),
                                    blurRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          TactileButton(
            width: 140,
            height: 46,
            onPressed: () => _startDueReview(context, totalWords),
            color: dueCount > 0 ? AppTheme.primary : AppTheme.hover,
            ledColor: Colors.white,
            isLedOn: dueCount > 0,
            child: Text(
              dueCount > 0 ? 'RUN REVIEW ($dueCount)' : 'START SESSION',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: dueCount > 0 ? AppTheme.displayBg : AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.shareTechMono(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  // Custom VFD Spectrum Visualizer
  Widget _buildSpectrumCard(List<int> data) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: AppTheme.displayDecoration(glow: true),
      child: CustomPaint(
        painter: VFDSpectrumPainter(data),
        child: Container(),
      ),
    );
  }

  // Stats Counters (Styled as hardware display windows)
  Widget _buildStatsRow(int mastered, int weak, int unlearned) {
    return Row(
      children: [
        Expanded(child: _buildStatCell('MASTERED', mastered, AppTheme.success)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCell('WEAK', weak, AppTheme.error)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCell('UNLEARNED', unlearned, AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildStatCell(String title, int count, Color ledColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 14.0),
      decoration: AppTheme.displayDecoration(glow: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.shareTechMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              // Tiny state indicator LED
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ledColor,
                  boxShadow: [
                    BoxShadow(
                      color: ledColor.withOpacity(0.5),
                      blurRadius: 2,
                    )
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            count.toString().padLeft(3, '0'),
            style: GoogleFonts.shareTechMono(
              fontSize: 22,
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
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          _buildModeRow(
            context,
            '01 // RETENTION QUIZ',
            'MULTIPLE CHOICE RETENTION ASSESSMENT',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: false,
              screenBuilder: (config) => QuizTestScreen(config: config),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _buildModeRow(
            context,
            '02 // SPELLING DICTATION',
            'ACTIVE WRITING AND RECALL ASSESSMENT',
            () => _startLearningConfig(
              context, totalWords,
              isTest: true, isSpelling: true,
              screenBuilder: (config) => SpellingTestScreen(config: config),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          _buildModeRow(
            context,
            '03 // AI RADIO CONSOLE',
            'INTERACTIVE SIMULATED AI COMMUNICATION',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: GoogleFonts.shareTechMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.shareTechMono(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            )
          ],
        ),
      ),
    );
  }

  // Recently Reviewed Data Table (styled like measuring log)
  Widget _buildRecentWordsTable(BuildContext context, List<Word> words) {
    final now = DateTime.now();
    final reviewedWords = words
        .where((w) => w.reviewedAt != null)
        .toList();
    reviewedWords.sort((a, b) => b.reviewedAt!.compareTo(a.reviewedAt!));
    
    final recent = reviewedWords.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.displayBg,
        border: Border.all(color: AppTheme.borderColor),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: recent.isEmpty
          ? SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'LOG: NO RECORDS IN SYSTEM MEMORY.',
                  style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            )
          : Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  color: AppTheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'INDEX/WORD',
                          style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'MEANING',
                          style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'STATE',
                          style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'RE-SCHED',
                          style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Table rows
                ...recent.map((word) {
                  final due = word.nextReviewAt == null || word.nextReviewAt!.isBefore(now);
                  String nextText = 'DUE';
                  Color nextColor = AppTheme.warning;

                  if (!due && word.nextReviewAt != null) {
                    final diff = word.nextReviewAt!.difference(now).inDays;
                    if (diff <= 0) {
                      nextText = 'TOMORROW';
                      nextColor = AppTheme.textSecondary;
                    } else {
                      nextText = 'IN ${diff + 1}D';
                      nextColor = AppTheme.textSecondary;
                    }
                  }

                  Color statusColor = AppTheme.textSecondary;
                  String statusText = 'NEW';
                  if (word.status == 1) {
                    statusColor = AppTheme.success;
                    statusText = 'MASTER';
                  } else if (word.status == 2) {
                    statusColor = AppTheme.error;
                    statusText = 'WEAK';
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                            '#${word.id.toString().padLeft(3, '0')} ${word.spelling.toUpperCase()}',
                            style: GoogleFonts.shareTechMono(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            word.meaningJa,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            statusText,
                            style: GoogleFonts.shareTechMono(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            nextText,
                            style: GoogleFonts.shareTechMono(fontSize: 10, fontWeight: FontWeight.bold, color: nextColor),
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

// ── Custom VFD Spectrum Painter ──
// Draws an audio equalizer style spectrum analyzer using segment blocks.
class VFDSpectrumPainter extends CustomPainter {
  final List<int> data;
  VFDSpectrumPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double paddingX = 6.0;
    final double spacingX = 4.0;
    final int maxSegments = 10;
    final double colWidth = (size.width - (paddingX * 2) - (spacingX * 6)) / 7;
    final double segSpacingY = 2.0;
    final double segHeight = (size.height - (segSpacingY * (maxSegments - 1))) / maxSegments;

    final double maxVal = data.reduce(max).toDouble();
    final double range = maxVal == 0 ? 1.0 : maxVal;

    for (int col = 0; col < 7; col++) {
      final double x = paddingX + col * (colWidth + spacingX);
      
      // Calculate how many segments should be lit
      final double rawNormalized = data[col] / range;
      final int litCount = (rawNormalized * maxSegments).round();

      for (int row = 0; row < maxSegments; row++) {
        // Draw bottom-up: index 0 is bottom, index 9 is top
        final double y = size.height - (row + 1) * (segHeight + segSpacingY) + segSpacingY;
        final bool isLit = row < litCount && data[col] > 0;

        Color blockColor;
        if (row < 5) {
          blockColor = AppTheme.success; // Bottom 5: Green
        } else if (row < 8) {
          blockColor = AppTheme.warning; // Middle 3: Yellow
        } else {
          blockColor = AppTheme.error;   // Top 2: Red
        }

        final paint = Paint()
          ..color = isLit ? blockColor : blockColor.withOpacity(0.06)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, colWidth, segHeight),
            const Radius.circular(0.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════
// LEARNING CONFIG BOTTOM SHEET (Physical tuning chassis style)
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
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor, width: 1.0),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TUNING_PANEL // CONFIG',
              style: GoogleFonts.shareTechMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 20),

            if (!widget.isSpelling) ...[
              _buildSectionTitle('SIGNAL DIRECTION'),
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

            _buildSectionTitle('CHASSIS SCOPE'),
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
                      style: GoogleFonts.shareTechMono(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('START ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endIdController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.shareTechMono(color: AppTheme.textPrimary, fontSize: 13),
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

            _buildSectionTitle('OUTPUT SORT ORDER'),
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
              _buildSectionTitle('QUESTIONS QUANTITY'),
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

            TactileButton(
              height: 48,
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
              color: AppTheme.primary,
              ledColor: Colors.white,
              isLedOn: true,
              child: Text(
                'INITIALIZE SESSION',
                style: GoogleFonts.shareTechMono(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.displayBg,
                  letterSpacing: 0.5,
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
      style: GoogleFonts.shareTechMono(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildChoiceItem(String title, bool selected, VoidCallback onTap) {
    return TactileButton(
      height: 38,
      onPressed: onTap,
      color: selected ? AppTheme.hover : AppTheme.surface,
      ledColor: AppTheme.primary,
      isLedOn: selected,
      child: Text(
        title,
        style: GoogleFonts.shareTechMono(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RangeType type) {
    final selected = _rangeType == type;
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      child: TactileButton(
        height: 34,
        onPressed: () => setState(() => _rangeType = type),
        color: selected ? AppTheme.hover : AppTheme.surface,
        ledColor: AppTheme.primary,
        isLedOn: selected,
        child: Text(
          label,
          style: GoogleFonts.shareTechMono(
            fontSize: 10,
            color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickRangeButton(int start, int end) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 6),
      child: TactileButton(
        height: 28,
        onPressed: () => _selectQuickRange(start, end),
        child: Text(
          '$start-$end',
          style: GoogleFonts.shareTechMono(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 10),
      filled: true,
      fillColor: AppTheme.displayBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm), borderSide: const BorderSide(color: AppTheme.borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm), borderSide: const BorderSide(color: AppTheme.borderColor)),
    );
  }
}
