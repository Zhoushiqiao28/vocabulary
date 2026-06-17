import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class TextScanScreen extends ConsumerStatefulWidget {
  const TextScanScreen({super.key});

  @override
  ConsumerState<TextScanScreen> createState() => _TextScanScreenState();
}

class _TextScanScreenState extends ConsumerState<TextScanScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isScanning = false;
  List<Map<String, String>> _scannedWords = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _scanText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isScanning = true;
      _scannedWords = [];
    });

    try {
      final gemini = ref.read(geminiServiceProvider);
      final words = await gemini.scanTextForWords(text);
      
      setState(() {
        _scannedWords = words;
      });

      if (words.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('単語を抽出できませんでした。短いテキスト、または有効な英語を入力してください。')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('エラーが発生しました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _importWords() async {
    if (_scannedWords.isEmpty) return;

    await ref.read(wordListProvider.notifier).importScannedWords(_scannedWords);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_scannedWords.length}語をオリジナル単語帳に追加しました！'),
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
        title: const Text('🔍 文脈テキストスキャナー'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '英文をインポート',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '英語の技術ドキュメントやニュースなどのテキストを貼り付けると、AIが文脈を理解した上で、重要単語を自動で抽出します。',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Input Field
              TextField(
                controller: _textController,
                maxLines: 8,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'ここに英文を入力するか、貼り付けてください...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.4)),
                  filled: true,
                  fillColor: AppTheme.surface,
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
              const SizedBox(height: 16),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _scanText,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isScanning
                      ? const SpinKitThreeBounce(color: Colors.white, size: 20)
                      : Text(
                          'AIで重要単語を抽出する',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Scanned Results
              if (_scannedWords.isNotEmpty) ...[
                Text(
                  '✨ 抽出された重要単語',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scannedWords.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _scannedWords[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.secondary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['spelling']!,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            item['meaning_ja']!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Import Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _importWords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'オリジナル単語帳に追加する',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
