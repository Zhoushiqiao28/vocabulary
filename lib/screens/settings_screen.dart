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
    // Load current values
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
          _testMessage = result['message'] as String? ?? (success ? 'Connection successful.' : 'Connection failed.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testMessage = 'Error: ${e.toString()}';
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
        content: Text('SETTINGS SAVED', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Profile Configuration'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'NAME',
                hint: 'Enter your name',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _interestsController,
                label: 'LEARNING INTERESTS (COMMA SEPARATED)',
                hint: 'e.g., Finance, Tech, Art, Gardening',
              ),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('Daily Target Goals'),
              const SizedBox(height: 12),
              Text(
                'DAILY REVIEW TARGET COUNT',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: AppTheme.cardDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.borderColor,
                          thumbColor: Colors.white,
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
                    const SizedBox(width: 16),
                    Text(
                      '$_dailyTarget',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('AI Language Engine'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _apiKeyController,
                label: 'GEMINI API KEY',
                hint: 'AIzaSy...',
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              Text(
                'GEMINI ENGINE MODEL',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildModelChoice('gemini-2.5-flash', 'Flash (Fast / Default)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModelChoice('gemini-2.5-pro', 'Pro (Smart / Creative)')),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Test Connection Button
              OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                child: _isTesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textSecondary),
                      )
                    : const Text('TEST API CONNECTION'),
              ),
              
              if (_testSuccess != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess! ? AppTheme.success.withOpacity(0.06) : AppTheme.error.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: _testSuccess! ? AppTheme.success.withOpacity(0.3) : AppTheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess! ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        color: _testSuccess! ? AppTheme.success : AppTheme.error,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testMessage ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: _testSuccess! ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              
              // Save Button
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('SAVE CONFIGURATION'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
        letterSpacing: -0.3,
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
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildModelChoice(String modelValue, String label) {
    final isSelected = _selectedModel == modelValue;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedModel = modelValue;
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
