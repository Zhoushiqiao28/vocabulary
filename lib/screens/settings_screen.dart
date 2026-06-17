import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _interestController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: profile.name);
    _keyController = TextEditingController(text: profile.apiKey);
    _interestController = TextEditingController(text: profile.interests.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    final apiKey = _keyController.text.trim();
    final interests = _interestController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await ref.read(userProfileProvider.notifier).updateProfile(
          name: name.isEmpty ? 'User' : name,
          apiKey: apiKey,
          interests: interests.isEmpty ? ['Technology'] : interests,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('設定を保存しました！'),
          backgroundColor: AppTheme.secondary,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ 設定'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'パーソナライズ設定',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AIがあなたの興味関心に合わせた例文を自動生成します。',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Name Field
              _buildTextField(
                label: 'ユーザー名',
                controller: _nameController,
                hint: '例：Hiro',
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 24),

              // Gemini API Key Field
              _buildTextField(
                label: 'Gemini APIキー',
                controller: _keyController,
                hint: 'AI機能を動かすためのキーを入力してください',
                icon: Icons.vpn_key_rounded,
                isPassword: true,
                helper: '※入力されたAPIキーはご自身の端末に安全に保存されます。キーがない場合はモックデータで動作します。',
              ),
              const SizedBox(height: 24),

              // Interests Field
              _buildTextField(
                label: 'あなたの興味関心（カンマ区切り）',
                controller: _interestController,
                hint: '例：宇宙開発, F1, K-POP, 旅行',
                icon: Icons.favorite_rounded,
                helper: '※AIが例文を作る際、このテーマに基づいたストーリーを生成します。',
              ),
              const SizedBox(height: 48),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    '設定を保存する',
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
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            prefixIcon: Icon(icon, color: AppTheme.primary),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3),
          ),
        ]
      ],
    );
  }
}
