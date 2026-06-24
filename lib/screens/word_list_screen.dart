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

  // Add / Edit Dialog
  void _showWordFormDialog({Word? word}) {
    final isEdit = word != null;
    final spellingController = TextEditingController(text: word?.spelling ?? '');
    final meaningController = TextEditingController(text: word?.meaningJa ?? '');
    final nuanceController = TextEditingController(text: word?.coreNuance ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.elevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: Text(
            isEdit ? 'Edit Vocabulary' : 'New Vocabulary',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: spellingController,
                  enabled: !isEdit,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Spelling (English)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meaningController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Meaning (Japanese)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nuanceController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Core Nuance / Image (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                final spelling = spellingController.text.trim();
                final meaning = meaningController.text.trim();
                final nuance = nuanceController.text.trim();

                if (spelling.isEmpty || meaning.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields.')),
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
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 36),
              ),
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }

  // Scanner Import Modal
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
            color: AppTheme.elevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'TEXT SCANNER / OCR SIMULATOR',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Paste English text from textbooks or articles. VocaBA will scan the content, filter unique words, and register them into your dictionary database.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: 12,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Paste paragraphs or scanned OCR text here...',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
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
                        'meaning_ja': 'Scanned word (Japanese translation pending)',
                      });
                    }
                  }

                  if (scanned.isNotEmpty) {
                    await ref.read(wordListProvider.notifier).importScannedWords(scanned);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully imported ${scanned.length} words from scan.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No valid words found in the text.')),
                    );
                  }
                },
                child: const Text('SCAN & IMPORT TEXT'),
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
          backgroundColor: AppTheme.elevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text('Delete word', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Text('Remove "${word.spelling}" from your dictionary?', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(wordListProvider.notifier).deleteWord(word.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Delete'),
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
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'Import from Scanner/Text',
            onPressed: _showImportTextSheet,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add new word',
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
                    style: const TextStyle(fontSize: 13),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search spelling or translation...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
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
                  // Filter horizontal list
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: _onlyFavorites ? AppTheme.warning : AppTheme.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              const Text('Favorites', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          selected: _onlyFavorites,
                          onSelected: (selected) => setState(() => _onlyFavorites = selected),
                          backgroundColor: Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, color: _onlyUserWords ? AppTheme.info : AppTheme.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              const Text('Custom', style: TextStyle(fontSize: 10)),
                            ],
                          ),
                          selected: _onlyUserWords,
                          onSelected: (selected) => setState(() => _onlyUserWords = selected),
                          backgroundColor: Colors.transparent,
                        ),
                        const SizedBox(width: 8),
                        ...[
                          {'label': 'All', 'val': -1},
                          {'label': 'New', 'val': 0},
                          {'label': 'Mastered', 'val': 1},
                          {'label': 'Weak', 'val': 2},
                        ].map((filter) {
                          final isSelected = _selectedStatusFilter == filter['val'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(filter['label'] as String, style: const TextStyle(fontSize: 10)),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedStatusFilter = filter['val'] as int;
                                  });
                                }
                              },
                              backgroundColor: Colors.transparent,
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

            // High-density Data Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              color: AppTheme.surface.withOpacity(0.4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'SPELLING',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'TRANSLATION',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'ACTIONS',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
                          Icon(Icons.folder_open_rounded, color: AppTheme.textMuted, size: 48),
                          const SizedBox(height: 12),
                          const Text('No records match query', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
    String statusText = 'New';
    if (word.status == 1) {
      statusColor = AppTheme.success;
      statusText = 'Mastered';
    } else if (word.status == 2) {
      statusColor = AppTheme.error;
      statusText = 'Weak';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Spelling + TTS icon
          Expanded(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    word.spelling,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 14, color: AppTheme.textSecondary),
                  onPressed: () => _speak(word.spelling),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (word.isSystem) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'Sys',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
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
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status trigger chip
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () {
                final nextStatus = (word.status + 1) % 3;
                ref.read(wordListProvider.notifier).updateWordStatus(word.id, nextStatus);
              },
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
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
                  child: Icon(
                    word.isFavorite ? Icons.star : Icons.star_border,
                    color: word.isFavorite ? AppTheme.warning : AppTheme.textMuted,
                    size: 16,
                  ),
                ),
                if (!word.isSystem) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showWordFormDialog(word: word),
                    child: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 14),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _confirmDelete(word),
                    child: const Icon(Icons.delete_rounded, color: AppTheme.error, size: 14),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
