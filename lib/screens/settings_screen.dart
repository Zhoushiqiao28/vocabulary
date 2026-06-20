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
  bool _isTesting = false;
  Map<String, dynamic>? _testResult;
  late String _selectedModel;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: profile.name);
    _keyController = TextEditingController(text: profile.apiKey);
    _interestController = TextEditingController(text: profile.interests.join(', '));
    _selectedModel = profile.geminiModel;
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
          geminiModel: _selectedModel,
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
              const SizedBox(height: 12),
              _buildConnectionTestWidget(),
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

  Future<void> _runConnectionTest() async {
    final key = _keyController.text.trim();
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final geminiService = ref.read(geminiServiceProvider);
    final result = await geminiService.testConnection(key);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
        if (result['success'] == true && result['bestModel'] != null) {
          _selectedModel = result['bestModel'];
        }
      });
    }
  }

  Widget _buildConnectionTestWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _runConnectionTest,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(_isTesting ? 'テスト中...' : 'APIキー接続テスト'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 8),
            if (!_isTesting && _testResult == null)
              Text(
                '接続状況を確認できます',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
          ],
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _testResult!['success'] == true
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _testResult!['success'] == true
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _testResult!['success'] == true
                          ? Icons.check_circle_rounded
                          : Icons.error_rounded,
                      color: _testResult!['success'] == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!['success'] == true ? '接続成功！' : '接続失敗',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _testResult!['success'] == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _testResult!['message'] ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_testResult!['success'] == true && _testResult!['bestModel'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '💡 会話や例文生成には、お使いのキーで利用可能な最新モデル「${_testResult!['bestModel']}」が自動選択され、設定保存時に適用されます。',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (_testResult!['advice'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '【アドバイス】\n${_testResult!['advice']}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                if (_testResult!['models'] != null && (_testResult!['models'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '利用可能なモデル:',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (_testResult!['models'] as List).map((m) {
                      final modelStr = m.toString();
                      final shortName = modelStr.replaceFirst('models/', '');
                      final isFlash = shortName.contains('gemini-1.5-flash');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isFlash ? AppTheme.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFlash ? AppTheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          shortName,
                          style: TextStyle(
                            color: isFlash ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: isFlash ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
