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
  final _nameController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _interestsController = TextEditingController();
  
  int _dailyTarget = 10;
  String _selectedModel = 'gemini-2.5-flash';
  
  bool _isTesting = false;
  bool? _testSuccess;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider);
      _nameController.text = profile.name;
      _apiKeyController.text = profile.apiKey;
      _interestsController.text = profile.interests.join(', ');
      setState(() {
        _dailyTarget = profile.dailyTarget;
        _selectedModel = profile.geminiModel;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testSuccess = null;
      _testMessage = null;
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final result = await gemini.testConnection(_apiKeyController.text.trim());
      final success = result['success'] as bool? ?? false;
      
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = success;
          _testMessage = result['message'] as String? ??
              (success ? '接続に成功しました' : '接続に失敗しました');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testMessage = 'エラー: ${e.toString()}';
        });
      }
    }
  }

  void _saveSettings() {
    final interests = _interestsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    ref.read(userProfileProvider.notifier).updateProfile(
      name: _nameController.text.trim().isEmpty ? 'Guest' : _nameController.text.trim(),
      dailyTarget: _dailyTarget,
      interests: interests,
      apiKey: _apiKeyController.text.trim(),
      geminiModel: _selectedModel,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '設定を保存しました',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        margin: const EdgeInsets.all(AppTheme.sp16),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          '設定',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.sp20,
            vertical: AppTheme.sp8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.sp8),

              // ── Profile Section ──
              _buildSectionTitle('プロフィール'),
              const SizedBox(height: AppTheme.sp16),
              _buildTextField(
                controller: _nameController,
                label: 'ユーザー名',
                hint: '名前を入力…',
              ),
              const SizedBox(height: AppTheme.sp16),
              _buildTextField(
                controller: _interestsController,
                label: '学習の興味（カンマ区切り）',
                hint: '例: 金融, テクノロジー, アート',
              ),
              
              const SizedBox(height: AppTheme.sp32),
              
              // ── Daily Goal Section ──
              _buildSectionTitle('学習目標'),
              const SizedBox(height: AppTheme.sp12),
              Text(
                '1日の復習目標',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.sp8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp16,
                  vertical: AppTheme.sp12,
                ),
                decoration: AppTheme.cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.hover,
                          thumbColor: Colors.white,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTickMarkColor: AppTheme.primary,
                          inactiveTickMarkColor: AppTheme.hover,
                        ),
                        child: Slider(
                          value: _dailyTarget.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          onChanged: (val) {
                            setState(() {
                              _dailyTarget = val.toInt();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.sp16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sp12,
                        vertical: AppTheme.sp4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text(
                        '$_dailyTarget 語',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.sp32),
              
              // ── AI Settings Section ──
              _buildSectionTitle('AI 設定'),
              const SizedBox(height: AppTheme.sp16),
              _buildTextField(
                controller: _apiKeyController,
                label: 'Gemini API キー',
                hint: 'AIzaSy...',
                obscureText: true,
              ),
              const SizedBox(height: AppTheme.sp16),
              
              Text(
                'Gemini モデル',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.sp8),
              Row(
                children: [
                  Expanded(child: _buildModelChoice('gemini-2.5-flash', 'Flash', '高速・標準')),
                  const SizedBox(width: AppTheme.sp12),
                  Expanded(child: _buildModelChoice('gemini-2.5-pro', 'Pro', '高精度')),
                ],
              ),
              
              const SizedBox(height: AppTheme.sp16),
              
              // Test Connection Button
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _isTesting ? null : _testConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.elevated,
                    foregroundColor: AppTheme.textPrimary,
                    disabledBackgroundColor: AppTheme.surface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                  child: _isTesting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primary,
                          ),
                        )
                      : Text(
                          '接続テスト',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              
              if (_testSuccess != null) ...[
                const SizedBox(height: AppTheme.sp12),
                Container(
                  padding: const EdgeInsets.all(AppTheme.sp12),
                  decoration: BoxDecoration(
                    color: (_testSuccess!
                        ? AppTheme.success
                        : AppTheme.error)
                        .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: (_testSuccess!
                          ? AppTheme.success
                          : AppTheme.error)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess!
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        size: 18,
                        color: _testSuccess! ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: AppTheme.sp8),
                      Expanded(
                        child: Text(
                          _testMessage ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _testSuccess! ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: AppTheme.sp48),
              
              // Save Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    '保存する',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sp32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.sp8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sp16,
              vertical: AppTheme.sp12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelChoice(String modelValue, String title, String subtitle) {
    final isSelected = _selectedModel == modelValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModel = modelValue;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12,
          vertical: AppTheme.sp12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? AppTheme.primary.withOpacity(0.5) : AppTheme.borderColor,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
