import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class LearningCalendarDialog extends ConsumerStatefulWidget {
  const LearningCalendarDialog({super.key});

  @override
  ConsumerState<LearningCalendarDialog> createState() => _LearningCalendarDialogState();
}

class _LearningCalendarDialogState extends ConsumerState<LearningCalendarDialog> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final words = ref.watch(wordListProvider);
    final profile = ref.watch(userProfileProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: AppTheme.elevatedDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'LEARNING LOG',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Month Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                ),
                Text(
                  '${_currentMonth.year} / ${_currentMonth.month.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar Grid
            _buildCalendarGrid(words, profile.dailyTarget),
            
            const SizedBox(height: 20),

            // Summary Bottom
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTINUITY STREAK',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${profile.streakDays} DAYS ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<Word> words, int dailyTarget) {
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    
    final Map<int, int> reviewCounts = {};
    for (final w in words) {
      if (w.reviewedAt != null &&
          w.reviewedAt!.year == _currentMonth.year &&
          w.reviewedAt!.month == _currentMonth.month) {
        final day = w.reviewedAt!.day;
        reviewCounts[day] = (reviewCounts[day] ?? 0) + 1;
      }
    }

    final today = DateTime.now();
    final isCurrentMonth = today.year == _currentMonth.year && today.month == _currentMonth.month;

    List<Widget> rows = [];
    
    // Weekdays header row
    rows.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) => 
          SizedBox(
            width: 28,
            child: Center(
              child: Text(
                day,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
    
    rows.add(const SizedBox(height: 8));

    // Calendar cells
    int currentDay = 1;
    for (int i = 0; i < 6; i++) {
      List<Widget> weekCells = [];
      for (int j = 1; j <= 7; j++) {
        if (i == 0 && j < firstWeekday) {
          weekCells.add(const SizedBox(width: 28, height: 28));
        } else if (currentDay > lastDayOfMonth.day) {
          weekCells.add(const SizedBox(width: 28, height: 28));
        } else {
          final count = reviewCounts[currentDay] ?? 0;
          final isToday = isCurrentMonth && currentDay == today.day;
          
          weekCells.add(_buildDayCell(currentDay, count, dailyTarget, isToday));
          currentDay++;
        }
      }
      
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekCells,
        ),
      );
      rows.add(const SizedBox(height: 4));
      
      if (currentDay > lastDayOfMonth.day) break;
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(int day, int count, int dailyTarget, bool isToday) {
    Color bgColor = Colors.transparent;
    Color textColor = AppTheme.textSecondary;
    Border? border;
    
    if (count > 0) {
      if (count >= dailyTarget) {
        bgColor = AppTheme.success;
        textColor = Colors.white;
      } else if (count >= dailyTarget / 2) {
        bgColor = AppTheme.success.withOpacity(0.4);
        textColor = AppTheme.textPrimary;
      } else {
        bgColor = AppTheme.success.withOpacity(0.12);
        textColor = AppTheme.success;
      }
    }

    if (isToday) {
      border = Border.all(color: AppTheme.primary, width: 1.2);
      if (count == 0) {
        textColor = AppTheme.primary;
      }
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: border,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isToday || count > 0 ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
