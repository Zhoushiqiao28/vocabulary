import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/providers.dart';

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
      // We test with the current text field value, not saved state
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
        content: Text('SETTINGS SAVED', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, letterSpacing: 1.0)),
        backgroundColor: const Color(0xFFE10600),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        margin: const EdgeInsets.all(24),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('PROFILE'),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'NAME',
                hint: 'Enter your name',
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _interestsController,
                label: 'INTERESTS (COMMA SEPARATED)',
                hint: 'e.g., F1, Programming, Cooking',
              ),
              
              const SizedBox(height: 48),
              
              _buildSectionTitle('GOALS'),
              const SizedBox(height: 24),
              Text(
                'DAILY TARGET',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFE10600),
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: Colors.white,
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              _buildSectionTitle('AI ENGINE'),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _apiKeyController,
                label: 'GEMINI API KEY',
                hint: 'AIz...',
                obscureText: true,
              ),
              const SizedBox(height: 24),
              
              Text(
                'MODEL',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildModelChip('gemini-2.5-flash', 'Flash (Fast)'),
                  _buildModelChip('gemini-2.5-pro', 'Pro (Smart)'),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Test Connection Button (Sharp outline)
              OutlinedButton(
                onPressed: _isTesting ? null : _testConnection,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: _isTesting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'TEST CONNECTION',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
              
              if (_testSuccess != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _testSuccess! ? const Color(0xFF34D399).withOpacity(0.1) : const Color(0xFFF87171).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        _testSuccess! ? Icons.check_circle_outline : Icons.error_outline,
                        color: _testSuccess! ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _testMessage ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: _testSuccess! ? const Color(0xFF34D399) : const Color(0xFFF87171),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 64),
              
              // Save Button (Full bleed red)
              ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE10600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: Text(
                  'SAVE CHANGES',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 40),
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
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
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
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.5),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.white.withOpacity(0.2)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE10600), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelChip(String modelValue, String label) {
    final isSelected = _selectedModel == modelValue;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedModel = modelValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
