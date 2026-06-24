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
          _testMessage = result['message'] as String? ?? (success ? 'CONNECTION SUCCESSFUL.' : 'CONNECTION FAILED.');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testMessage = 'ERROR: ${e.toString().toUpperCase()}';
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
          'LOG: SETTINGS RE-CALIBRATED SUCCESSFULLY.',
          style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        backgroundColor: AppTheme.success,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('CALIBRATION // SETTINGS'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('CHASSIS CONFIGURATION'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _nameController,
                label: 'USER_NAME',
                hint: 'ENTER OPERATOR NAME...',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _interestsController,
                label: 'LEARNING INTERESTS (COMMA SEPARATED)',
                hint: 'E.G., FINANCE, TECH, ART, GARDENING',
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('POTENTIOMETER GOALS'),
              const SizedBox(height: 12),
              Text(
                'DAILY REVIEW TARGET LEVEL',
                style: GoogleFonts.shareTechMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: AppTheme.displayDecoration(glow: false),
                child: Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppTheme.primary,
                          inactiveTrackColor: AppTheme.borderColor,
                          thumbColor: Colors.white,
                          trackHeight: 1,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTickMarkColor: AppTheme.primary,
                          inactiveTickMarkColor: AppTheme.borderColor,
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
                      '$_dailyTarget UNIT',
                      style: GoogleFonts.shareTechMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('AI DIALOG ENGINE TUNER'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _apiKeyController,
                label: 'GEMINI API KEY (TELEMETRY AUTHS)',
                hint: 'AIzaSy...',
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              Text(
                'GEMINI CORE MODEL STATE',
                style: GoogleFonts.shareTechMono(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildModelChoice('gemini-2.5-flash', 'FLASH (FAST / DEFAULT)')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModelChoice('gemini-2.5-pro', 'PRO (SMART / CREATIVE)')),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Test Connection Button (styled as tactile check key)
              TactileButton(
                height: 38,
                onPressed: _isTesting ? null : _testConnection,
                child: _isTesting
                    ? const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primary),
                      )
                    : Text(
                        'TEST TRANSCEIVER SIGNAL',
                        style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
              ),
              
              if (_testSuccess != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.displayBg,
                    border: Border.all(
                      color: _testSuccess! ? AppTheme.success : AppTheme.error,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Status LED dot
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _testSuccess! ? AppTheme.success : AppTheme.error,
                          boxShadow: [
                            BoxShadow(color: _testSuccess! ? AppTheme.success : AppTheme.error, blurRadius: 4),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testMessage ?? '',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 11,
                            color: _testSuccess! ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 36),
              
              // Save Button
              TactileButton(
                height: 48,
                onPressed: _saveSettings,
                color: AppTheme.primary,
                ledColor: Colors.white,
                isLedOn: true,
                child: Text(
                  'SAVE CONFIGURATION',
                  style: GoogleFonts.shareTechMono(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.displayBg,
                    letterSpacing: 0.5,
                  ),
                ),
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
      style: GoogleFonts.shareTechMono(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
        letterSpacing: 0.5,
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
          style: GoogleFonts.shareTechMono(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.shareTechMono(fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 13),
            prefixText: 'PARM > ',
            prefixStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildModelChoice(String modelValue, String label) {
    final isSelected = _selectedModel == modelValue;
    return TactileButton(
      height: 40,
      onPressed: () {
        setState(() {
          _selectedModel = modelValue;
        });
      },
      color: isSelected ? AppTheme.hover : AppTheme.surface,
      ledColor: AppTheme.primary,
      isLedOn: isSelected,
      child: Text(
        label,
        style: GoogleFonts.shareTechMono(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
