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
  
  // Filters
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
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          title: Text(
            isEdit ? '単語を編集' : '新しい単語を追加',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: spellingController,
                  enabled: !isEdit, // スペルは編集不可にするか、新規時のみ
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: '英単語 (Spelling)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: meaningController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: '日本語訳 (Meaning)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nuanceController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'コアイメージ/ニュアンス (任意)',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.black12,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final spelling = spellingController.text.trim();
                final meaning = meaningController.text.trim();
                final nuance = nuanceController.text.trim();

                if (spelling.isEmpty || meaning.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('英単語と日本語訳を入力してください。')),
                  );
                  return;
                }

                final notifier = ref.read(wordListProvider.notifier);
                if (isEdit) {
                  notifier.editWord(word!.id, spelling, meaning, nuance.isEmpty ? null : nuance);
                } else {
                  notifier.addWord(spelling, meaning, nuance.isEmpty ? null : nuance);
                }

                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEdit ? '保存' : '追加'),
            ),
          ],
        );
      },
    );
  }

  // Delete Confirm
  void _confirmDelete(Word word) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('単語の削除', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('${word.spelling} を単語帳から削除しますか？', style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(wordListProvider.notifier).deleteWord(word.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('削除', style: TextStyle(color: Colors.white)),
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
      // 1. Search Query Match (Spelling or Meaning)
      final query = _searchQuery.toLowerCase();
      final matchesSearch = word.spelling.toLowerCase().contains(query) ||
          word.meaningJa.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // 2. Status Filter
      if (_selectedStatusFilter != -1 && word.status != _selectedStatusFilter) {
        return false;
      }

      // 3. Favorites Only
      if (_onlyFavorites && !word.isFavorite) {
        return false;
      }

      // 4. User Words Only
      if (_onlyUserWords && word.isSystem) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '📖 単語帳リスト',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWordFormDialog(),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: '英単語・意味で検索...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.3)),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
            ),

            // Filters Horizontal List
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Favorites Filter Chip
                  FilterChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.orangeAccent, size: 14),
                        SizedBox(width: 4),
                        Text('お気に入り', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    selected: _onlyFavorites,
                    onSelected: (selected) {
                      setState(() {
                        _onlyFavorites = selected;
                      });
                    },
                    selectedColor: Colors.orangeAccent.withOpacity(0.2),
                    checkmarkColor: Colors.orangeAccent,
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  const SizedBox(width: 8),

                  // User Custom Words Filter Chip
                  FilterChip(
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: AppTheme.secondary, size: 14),
                        SizedBox(width: 4),
                        Text('自作単語', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    selected: _onlyUserWords,
                    onSelected: (selected) {
                      setState(() {
                        _onlyUserWords = selected;
                      });
                    },
                    selectedColor: AppTheme.secondary.withOpacity(0.2),
                    checkmarkColor: AppTheme.secondary,
                    backgroundColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  const SizedBox(width: 8),

                  // Status Chips
                  ...[
                    {'label': '全て', 'val': -1},
                    {'label': '未学習', 'val': 0},
                    {'label': '覚えた', 'val': 1},
                    {'label': '覚えてない', 'val': 2},
                  ].map((filter) {
                    final isSelected = _selectedStatusFilter == filter['val'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter['label'] as String, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStatusFilter = filter['val'] as int;
                            });
                          }
                        },
                        selectedColor: AppTheme.primary.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                        backgroundColor: AppTheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Words Count Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '該当件数: ${filteredWords.length} 件',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Word List
            Expanded(
              child: filteredWords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded, color: AppTheme.textSecondary.withOpacity(0.2), size: 64),
                          const SizedBox(height: 16),
                          const Text('単語が見つかりません', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredWords.length,
                      itemBuilder: (context, index) {
                        final word = filteredWords[index];
                        return _buildWordTile(word);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordTile(Word word) {
    // Status color
    Color statusColor = Colors.white24;
    String statusText = '未学習';
    if (word.status == 1) {
      statusColor = Colors.teal;
      statusText = '覚えた';
    } else if (word.status == 2) {
      statusColor = Colors.redAccent;
      statusText = '覚えてない';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Left Content (Spelling & Meaning)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Spelling
                      Text(
                        word.spelling,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Pronunciation Speak Button
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 18, color: AppTheme.secondary),
                        onPressed: () => _speak(word.spelling),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: '発音を聞く',
                      ),
                      // System Badge
                      if (word.isSystem) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'System',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Meaning
                  Text(
                    word.meaningJa,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (word.coreNuance != null && word.coreNuance!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'イメージ: ${word.coreNuance}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.accent,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ]
                ],
              ),
            ),

            // Right Actions (Star, Status Dropdown, CRUD icons)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favorite Star
                IconButton(
                  icon: Icon(
                    word.isFavorite ? Icons.star : Icons.star_border,
                    color: word.isFavorite ? Colors.orangeAccent : AppTheme.textSecondary,
                    size: 24,
                  ),
                  onPressed: () {
                    ref.read(wordListProvider.notifier).toggleFavorite(word.id);
                  },
                ),

                // Status Cycle button
                InkWell(
                  onTap: () {
                    // Cycles: 0 -> 1 -> 2 -> 0
                    final nextStatus = (word.status + 1) % 3;
                    ref.read(wordListProvider.notifier).updateWordStatus(word.id, nextStatus);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: word.status == 0 ? AppTheme.textSecondary : statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Custom words edit/delete icons (Protected if isSystem is true)
                if (!word.isSystem) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => _showWordFormDialog(word: word),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDelete(word),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ] else ...[
                  // Hidden spacing for alignment
                  const SizedBox(width: 44),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
