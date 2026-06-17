import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header (User Profile & AI Welcome Message)
              _buildHeader(),
              const SizedBox(height: 32),

              // AI Motivate Message (Glassmorphism card)
              _buildAIMessageCard(),
              const SizedBox(height: 32),

              // Learning Stats / Heatmap Placeholder
              _buildHeatmapCard(),
              const SizedBox(height: 32),

              // Action Buttons / Navigation Cards
              _buildSectionTitle('⚡ クイック学習メニュー'),
              const SizedBox(height: 16),
              _buildActionCard(
                title: '英単語カード学習',
                description: '3方向スワイプでサクサク記憶。AIによる興味関心例文つき。',
                icon: Icons.style_rounded,
                color: AppTheme.primary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('スワイプカード学習画面は次のフェーズで実装されます')),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                title: 'AI対話テスト (チャット)',
                description: '学んだ単語を実際に使って会話。AIからのリアルタイム添削。',
                icon: Icons.chat_bubble_rounded,
                color: AppTheme.secondary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AIチャット画面は次のフェーズで実装されます')),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                title: '文脈テキストスキャン',
                description: '技術ドキュメントや英語ニュースから、重要単語を瞬時に抽出。',
                icon: Icons.document_scanner_rounded,
                color: AppTheme.accent,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('テキストスキャナー画面は次のフェーズで実装されます')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome Back,',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Hiro 👋',
              style: GoogleFonts.outfit(
                fontSize: 28,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // Simple Profile Icon with neon accent
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]
          ),
          child: const Center(
            child: Icon(Icons.person_outline_rounded, color: Colors.white),
          ),
        )
      ],
    );
  }

  Widget _buildAIMessageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: AppTheme.glassBoxDecoration(color: AppTheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Personal Agent',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '「F1」と「宇宙開発」に関する新しいニュースが更新されています！今日の単語学習に宇宙船開発の例文を混ぜておきました。3分間集中してみましょう。',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '学習ロードマップ',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '5日連続学習中',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Simple Grid representing contribution days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 15,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 75,
            itemBuilder: (context, index) {
              Color cellColor = AppTheme.surface;
              if (index == 12 || index == 24 || index == 35 || index == 48 || index == 50 || index > 65) {
                cellColor = AppTheme.primary;
              } else if (index == 15 || index == 28 || index == 42 || index == 60) {
                cellColor = AppTheme.primary.withOpacity(0.4);
              } else if (index == 2 || index == 5 || index == 40 || index == 55) {
                cellColor = AppTheme.secondary.withOpacity(0.5);
              }
              return Container(
                decoration: BoxDecoration(
                  color: cellColor == AppTheme.surface ? Colors.white.withOpacity(0.05) : cellColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less ', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Container(width: 8, height: 8, color: Colors.white.withOpacity(0.05)),
              const SizedBox(width: 2),
              Container(width: 8, height: 8, color: AppTheme.primary.withOpacity(0.4)),
              const SizedBox(width: 2),
              Container(width: 8, height: 8, color: AppTheme.primary),
              const SizedBox(width: 4),
              Text('More', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
