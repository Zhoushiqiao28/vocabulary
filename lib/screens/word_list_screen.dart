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

  // ─── Next Review Date Formatting ───
  String _formatNextReview(DateTime? nextReviewAt) {
    if (nextReviewAt == null) return '未学習';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDay = DateTime(nextReviewAt.year, nextReviewAt.month, nextReviewAt.day);

    if (reviewDay.isBefore(today)) return '復習対象';
    if (reviewDay.isAtSameMomentAs(today)) return '今日';

    final daysUntil = reviewDay.difference(today).inDays;
    if (daysUntil <= 7) return '$daysUntil日後';

    return '${nextReviewAt.month}/${nextReviewAt.day}';
  }

  Color _nextReviewColor(DateTime? nextReviewAt) {
    if (nextReviewAt == null) return AppTheme.textMuted;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDay = DateTime(nextReviewAt.year, nextReviewAt.month, nextReviewAt.day);

    if (reviewDay.isBefore(today)) return AppTheme.warning;
    if (reviewDay.isAtSameMomentAs(today)) return AppTheme.error;

    final daysUntil = reviewDay.difference(today).inDays;
    if (daysUntil <= 7) return AppTheme.info;

    return AppTheme.textSecondary;
  }

  // ─── Add / Edit Dialog ───
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
            isEdit ? '単語を編集' : '新しい単語を追加',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: spellingController,
                  enabled: !isEdit,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: _inputDecoration('スペリング（英語）'),
                ),
                const SizedBox(height: AppTheme.sp12),
                TextField(
                  controller: meaningController,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: _inputDecoration('意味（日本語）'),
                ),
                const SizedBox(height: AppTheme.sp12),
                TextField(
                  controller: nuanceController,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: _inputDecoration('ニュアンス（任意）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'キャンセル',
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: AppTheme.sp4),
            ElevatedButton(
              onPressed: () {
                final spelling = spellingController.text.trim();
                final meaning = meaningController.text.trim();
                final nuance = nuanceController.text.trim();

                if (spelling.isEmpty || meaning.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'スペリングと意味は必須です',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: AppTheme.error,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.sp16,
                  vertical: AppTheme.sp8,
                ),
              ),
              child: Text(
                isEdit ? '保存' : '追加',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Text Import Sheet ───
  void _showImportTextSheet() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: AppTheme.elevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            border: const Border(
              top: BorderSide(color: AppTheme.borderColor),
            ),
          ),
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.sp16),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
              ),
              Text(
                'テキストから単語を取り込み',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.sp4),
              Text(
                '英語テキストを貼り付けると、単語を自動的に抽出します。',
                style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppTheme.sp16),
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ここにテキストを貼り付け…',
                    hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.sp16),
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
                        'meaning_ja': '翻訳待ち',
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
                          '${scanned.length}件の単語を取り込みました',
                          style: GoogleFonts.outfit(),
                        ),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '有効な単語が見つかりませんでした',
                          style: GoogleFonts.outfit(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Text(
                  '取り込み開始',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Delete Confirmation ───
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
          title: Text(
            '単語を削除',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.error,
            ),
          ),
          content: Text(
            '「${word.spelling}」を完全に削除しますか？この操作は取り消せません。',
            style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'キャンセル',
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(width: AppTheme.sp4),
            ElevatedButton(
              onPressed: () {
                ref.read(wordListProvider.notifier).deleteWord(word.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: Text(
                '削除',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
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

    // Compute stats
    final totalCount = allWords.length;
    final masteredCount = allWords.where((w) => w.status == 1).length;
    final masteredRatio = totalCount > 0 ? masteredCount / totalCount : 0.0;

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
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.sp20, AppTheme.sp16, AppTheme.sp20, AppTheme.sp4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '単語ライブラリ',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.sp4),
                            Text(
                              '$totalCount語　習得 $masteredCount語',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.file_upload_outlined, size: 20, color: AppTheme.textSecondary),
                        tooltip: 'テキストから取り込み',
                        onPressed: _showImportTextSheet,
                      ),
                      const SizedBox(width: AppTheme.sp4),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, size: 22, color: AppTheme.primary),
                        tooltip: '単語を追加',
                        onPressed: () => _showWordFormDialog(),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.sp12),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: masteredRatio,
                      minHeight: 4,
                      backgroundColor: AppTheme.elevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.sp8),

            // ─── Search Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp20),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textPrimary),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textMuted),
                  hintText: '単語や意味を検索…',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 14),
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
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.textSecondary),
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
            ),

            const SizedBox(height: AppTheme.sp12),

            // ─── Filter Chips ───
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp20),
                children: [
                  _buildFilterChip(
                    label: 'お気に入り',
                    icon: Icons.star_rounded,
                    isSelected: _onlyFavorites,
                    activeColor: AppTheme.warning,
                    onTap: () => setState(() => _onlyFavorites = !_onlyFavorites),
                  ),
                  const SizedBox(width: AppTheme.sp8),
                  _buildFilterChip(
                    label: 'カスタム',
                    icon: Icons.person_rounded,
                    isSelected: _onlyUserWords,
                    activeColor: AppTheme.info,
                    onTap: () => setState(() => _onlyUserWords = !_onlyUserWords),
                  ),
                  const SizedBox(width: AppTheme.sp12),
                  // Divider
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    color: AppTheme.borderColor,
                  ),
                  const SizedBox(width: AppTheme.sp12),
                  ...[
                    {'label': 'すべて', 'val': -1, 'color': AppTheme.primary},
                    {'label': '未学習', 'val': 0, 'color': AppTheme.textSecondary},
                    {'label': '習得', 'val': 1, 'color': AppTheme.success},
                    {'label': '苦手', 'val': 2, 'color': AppTheme.error},
                  ].map((filter) {
                    final isSelected = _selectedStatusFilter == filter['val'];
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.sp8),
                      child: _buildFilterChip(
                        label: filter['label'] as String,
                        isSelected: isSelected,
                        activeColor: filter['color'] as Color,
                        onTap: () {
                          setState(() {
                            _selectedStatusFilter = filter['val'] as int;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.sp12),

            // ─── Results count ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp20),
              child: Row(
                children: [
                  Text(
                    '${filteredWords.length}件の結果',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.sp8),

            // ─── Word List ───
            Expanded(
              child: filteredWords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: AppTheme.textMuted,
                            size: 48,
                          ),
                          const SizedBox(height: AppTheme.sp12),
                          Text(
                            '該当する単語がありません',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: AppTheme.sp4),
                          Text(
                            '検索条件やフィルターを変更してみてください',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp20),
                      itemCount: filteredWords.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: AppTheme.borderColor,
                      ),
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

  // ─── Filter Chip Builder ───
  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp12,
          vertical: AppTheme.sp4,
        ),
        decoration: isSelected
            ? AppTheme.statusChipDecoration(color: activeColor, filled: true)
            : AppTheme.cardDecoration(color: AppTheme.surface, radius: AppTheme.radiusSm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : AppTheme.textMuted,
              ),
              const SizedBox(width: AppTheme.sp4),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Word Row ───
  Widget _buildWordRow(Word word) {
    final statusColor = AppTheme.statusColor(word.status);
    final statusLabel = AppTheme.statusLabel(word.status);
    final nextReviewText = _formatNextReview(word.nextReviewAt);
    final nextReviewColor = _nextReviewColor(word.nextReviewAt);

    return InkWell(
      onTap: () => _showWordFormDialog(word: word),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.sp12),
        child: Row(
          children: [
            // ── Left: Word info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Spelling row
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          word.spelling,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.sp8),
                      GestureDetector(
                        onTap: () => _speak(word.spelling),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (word.isFavorite) ...[
                        const SizedBox(width: AppTheme.sp8),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppTheme.warning,
                        ),
                      ],
                      if (!word.isSystem) ...[
                        const SizedBox(width: AppTheme.sp8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.sp4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'カスタム',
                            style: GoogleFonts.outfit(
                              color: AppTheme.info,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.sp4),
                  // Meaning
                  Text(
                    word.meaningJa,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppTheme.sp12),

            // ── Right: Status, Next Review, Actions ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Status chip
                GestureDetector(
                  onTap: () {
                    final nextStatus = (word.status + 1) % 3;
                    ref.read(wordListProvider.notifier).updateWordStatus(word.id, nextStatus);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.sp8,
                      vertical: AppTheme.sp4,
                    ),
                    decoration: AppTheme.statusChipDecoration(
                      color: statusColor,
                      filled: true,
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.sp4),
                // Next review date
                Text(
                  nextReviewText,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: nextReviewColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(width: AppTheme.sp12),

            // ── Actions column ──
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Favorite toggle
                GestureDetector(
                  onTap: () => ref.read(wordListProvider.notifier).toggleFavorite(word.id),
                  child: Icon(
                    word.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: word.isFavorite ? AppTheme.warning : AppTheme.textMuted,
                  ),
                ),
                if (!word.isSystem) ...[
                  const SizedBox(height: AppTheme.sp8),
                  GestureDetector(
                    onTap: () => _confirmDelete(word),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.textMuted,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Input Decoration Helper ───
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: AppTheme.textSecondary, fontSize: 13),
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
    );
  }
}
