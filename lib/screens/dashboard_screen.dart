import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'card_learning_screen.dart';
import 'quiz_test_screen.dart';
import 'spelling_test_screen.dart';
import 'chat_selection_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final words = ref.watch(wordListProvider);

    final masteredCount = words.where((e) => e.status == 1).toList().length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header
              _buildHeader(context, profile),
              const SizedBox(height: 16),

              // Compact AI Message Banner
              _buildAIMessageBanner(profile),
              const SizedBox(height: 24),

              // HUGE main start card
              Expanded(
                flex: 4,
                child: _buildMainStartCard(context),
              ),
              const SizedBox(height: 20),

              // Practice modes
              Expanded(
                flex: 4,
                child: Column(
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
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const QuizTestScreen()),
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
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const SpellingTestScreen()),
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
                      description: '覚えた単語を使ってAIと自然な英会話',
                      icon: Icons.chat_bubble_rounded,
                      color: AppTheme.primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ChatSelectionScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Bottom mini footer
              _buildMiniFooter(masteredCount, words.length),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile) {
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
                Container(
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
                )
              ],
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
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

  Widget _buildMainStartCard(BuildContext context) {
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
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CardLearningScreen()),
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
            'VocaBA v2.0',
            style: GoogleFonts.outfit(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 10),
          )
        ],
      ),
    );
  }
}
