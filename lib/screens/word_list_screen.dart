import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class WordListScreen extends ConsumerStatefulWidget {
  const WordListScreen({super.key});

  @override
  ConsumerState<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends ConsumerState<WordListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  
  String _searchQuery = '';
  int _selectedStatusFilter = -1; // -1: All, 0: Unlearned, 1: Mastered, 2: Memorizing
  bool _onlyFavorites = false;
  bool _onlyUserWords = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  // Add / Edit Dialog (styled as hardware config panel)
  void _showWordFormDialog({Word? word}) {
    final isEdit = word != null;
    final spellingController = TextEditingController(text: word?.spelling ?? '');
    final meaningController = TextEditingController(text: word?.meaningJa ?? '');
    final nuanceController = TextEditingController(text: word?.coreNuance ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppTheme.borderColor),
          ),
          title: Text(
            isEdit ? 'EDIT_WORD // PARAMETER_TUNING' : 'NEW_WORD // DATABASE_REGISTER',
            style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: spellingController,
                  enabled: !isEdit,
                  style: GoogleFonts.shareTechMono(fontSize: 13),
                  decoration: _inputDecoration('SPELLING (ENGLISH)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meaningController,
                  style: GoogleFonts.shareTechMono(fontSize: 13),
                  decoration: _inputDecoration('MEANING (JAPANESE)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nuanceController,
                  style: GoogleFonts.shareTechMono(fontSize: 13),
                  decoration: _inputDecoration('NUANCE (OPTIONAL)'),
                ),
              ],
            ),
          ),
          actions: [
            TactileButton(
              width: 80,
              height: 34,
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: GoogleFonts.shareTechMono(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            TactileButton(
              width: 80,
              height: 34,
              onPressed: () {
                final spelling = spellingController.text.trim();
                final meaning = meaningController.text.trim();
                final nuance = nuanceController.text.trim();

                if (spelling.isEmpty || meaning.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'ERROR: REQUIRED FIELDS EMPTY.',
                        style: GoogleFonts.shareTechMono(),
                      ),
                    ),
                  );
                  return;
                }

                final notifier = ref.read(wordListProvider.notifier);
                if (word != null) {
                  notifier.editWord(word.id, spelling, meaning, nuance.isEmpty ? null : nuance);
                } else {
                  notifier.addWord(spelling, meaning, nuance.isEmpty ? null : nuance);
                }

                Navigator.pop(context);
              },
              color: AppTheme.primary,
              child: Text(
                isEdit ? 'SAVE' : 'ADD',
                style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.displayBg, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Scanner Import Modal (styled as OCR text console)
  void _showImportTextSheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'OCR_TEXT_SCANNER // TELEMETRY_IMPORT',
                style: GoogleFonts.shareTechMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'PASTE TEXT TO PARSE AND INTEGRATE UNIQUE ENGLISH VOCABULARY TERMS.',
                style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 10),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: 12,
                  style: GoogleFonts.spaceMono(fontSize: 12, color: AppTheme.success),
                  decoration: InputDecoration(
                    prefixText: 'SCANNER > ',
                    prefixStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 13),
                    hintText: 'PASTE SCAN DATA HERE...',
                    hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 13),
                    fillColor: AppTheme.displayBg,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TactileButton(
                height: 44,
                onPressed: () async {
                  final text = textController.text.trim();
                  if (text.isEmpty) return;

                  // Clean text and extract words longer than 3 letters
                  final regExp = RegExp(r'[a-zA-Z]+');
                  final matches = regExp.allMatches(text);
                  final uniqueWords = matches.map((m) => m.group(0)!.toLowerCase()).toSet();
                  
                  List<Map<String, String>> scanned = [];
                  for (var w in uniqueWords) {
                    if (w.length > 3) {
                      scanned.add({
                        'spelling': w,
                        'meaning_ja': 'PENDING_TRANSLATION',
                      });
                    }
                  }

                  if (scanned.isNotEmpty) {
                    await ref.read(wordListProvider.notifier).importScannedWords(scanned);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'LOG: IMPORTED ${scanned.length} WORDS SUCCESSFULLY.',
                          style: GoogleFonts.shareTechMono(),
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'ERROR: NO VALID WORDS FOUND.',
                          style: GoogleFonts.shareTechMono(),
                        ),
                      ),
                    );
                  }
                },
                color: AppTheme.primary,
                child: Text(
                  'SCAN & IMPORT DATA',
                  style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, color: AppTheme.displayBg),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(Word word) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: AppTheme.borderColor),
          ),
          title: Text(
            'DELETE_WORD // DESTRUCTIVE_ACTION',
            style: GoogleFonts.shareTechMono(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.error),
          ),
          content: Text(
            'REMOVE "${word.spelling.toUpperCase()}" PERMANENTLY FROM CHASSIS MEMORY?',
            style: GoogleFonts.shareTechMono(fontSize: 11, color: AppTheme.textSecondary),
          ),
          actions: [
            TactileButton(
              width: 80,
              height: 34,
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: GoogleFonts.shareTechMono(fontSize: 11)),
            ),
            const SizedBox(width: 8),
            TactileButton(
              width: 80,
              height: 34,
              onPressed: () {
                ref.read(wordListProvider.notifier).deleteWord(word.id);
                Navigator.pop(context);
              },
              color: AppTheme.error,
              child: Text(
                'DELETE',
                style: GoogleFonts.shareTechMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allWords = ref.watch(wordListProvider);

    // Apply Filter & Search
    final filteredWords = allWords.where((word) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = word.spelling.toLowerCase().contains(query) ||
          word.meaningJa.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_selectedStatusFilter != -1 && word.status != _selectedStatusFilter) {
        return false;
      }

      if (_onlyFavorites && !word.isFavorite) {
        return false;
      }

      if (_onlyUserWords && word.isSystem) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('WORD LIBRARY DIRECTORY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, size: 16),
            tooltip: 'Import Scan',
            onPressed: _showImportTextSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Add Term',
            onPressed: () => _showWordFormDialog(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Headers
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.shareTechMono(fontSize: 13),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      prefixText: 'SEARCH > ',
                      prefixStyle: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 13),
                      hintText: 'SEARCH SPELLING OR TRANSLATION...',
                      hintStyle: GoogleFonts.shareTechMono(color: AppTheme.textMuted, fontSize: 13),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Filter horizontal row with TactileButtons
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 6),
                          child: TactileButton(
                            height: 28,
                            onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
                            color: _onlyFavorites ? AppTheme.hover : AppTheme.surface,
                            ledColor: AppTheme.warning,
                            isLedOn: _onlyFavorites,
                            child: Text('FAVORITES', style: GoogleFonts.shareTechMono(fontSize: 10)),
                          ),
                        ),
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 6),
                          child: TactileButton(
                            height: 28,
                            onPressed: () => setState(() => _onlyUserWords = !_onlyUserWords),
                            color: _onlyUserWords ? AppTheme.hover : AppTheme.surface,
                            ledColor: AppTheme.info,
                            isLedOn: _onlyUserWords,
                            child: Text('CUSTOM_ONLY', style: GoogleFonts.shareTechMono(fontSize: 10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ...[
                          {'label': 'ALL', 'val': -1, 'led': AppTheme.primary},
                          {'label': 'NEW', 'val': 0, 'led': AppTheme.textSecondary},
                          {'label': 'MASTERED', 'val': 1, 'led': AppTheme.success},
                          {'label': 'WEAK', 'val': 2, 'led': AppTheme.error},
                        ].map((filter) {
                          final isSelected = _selectedStatusFilter == filter['val'];
                          return Container(
                            width: 90,
                            margin: const EdgeInsets.only(right: 6),
                            child: TactileButton(
                              height: 28,
                              onPressed: () {
                                setState(() {
                                  _selectedStatusFilter = filter['val'] as int;
                                });
                              },
                              color: isSelected ? AppTheme.hover : AppTheme.surface,
                              ledColor: filter['led'] as Color,
                              isLedOn: isSelected,
                              child: Text(
                                filter['label'] as String,
                                style: GoogleFonts.shareTechMono(fontSize: 10),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // High-density Data Table header (measuring log style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: AppTheme.displayBg,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'INDEX/SPELLING',
                      style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'TRANSLATION_LOG',
                      style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'SRS_STATE',
                      style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'OPERATE',
                      style: GoogleFonts.shareTechMono(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Directory rows
            Expanded(
              child: filteredWords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_open_rounded, color: AppTheme.textMuted, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            'LOG: NO RECORDS MATCH QUERY.',
                            style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredWords.length,
                      itemBuilder: (context, index) {
                        final word = filteredWords[index];
                        return _buildWordRow(word);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordRow(Word word) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Spelling + play audio button
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '#${word.id.toString().padLeft(3, '0')} ${word.spelling.toUpperCase()}',
                    style: GoogleFonts.shareTechMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 12, color: AppTheme.textSecondary),
                  onPressed: () => _speak(word.spelling),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (word.isSystem) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                    child: Text(
                      'SYS',
                      style: GoogleFonts.shareTechMono(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]
              ],
            ),
          ),

          // Translation
          Expanded(
            flex: 3,
            child: Text(
              word.meaningJa,
              style: GoogleFonts.shareTechMono(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status state (interactable text button)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                final nextStatus = (word.status + 1) % 3;
                ref.read(wordListProvider.notifier).updateWordStatus(word.id, nextStatus);
              },
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 6.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: [
                        BoxShadow(color: statusColor, blurRadius: 2),
                      ],
                    ),
                  ),
                  Text(
                    statusText,
                    style: GoogleFonts.shareTechMono(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Favorite / Edit / Delete actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => ref.read(wordListProvider.notifier).toggleFavorite(word.id),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: word.isFavorite ? AppTheme.warning : AppTheme.warning.withOpacity(0.1),
                      border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                      boxShadow: word.isFavorite
                          ? [
                              BoxShadow(color: AppTheme.warning.withOpacity(0.6), blurRadius: 3),
                            ]
                          : null,
                    ),
                  ),
                ),
                if (!word.isSystem) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showWordFormDialog(word: word),
                    child: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 12),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _confirmDelete(word),
                    child: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 12),
                  ),
                ]
              ],
            ),
          ),
        ],
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
