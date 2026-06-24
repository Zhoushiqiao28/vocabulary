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
      insetPadding: const EdgeInsets.all(AppTheme.sp16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: AppTheme.cardDecoration(color: AppTheme.surface, radius: AppTheme.radiusLg),
        padding: const EdgeInsets.all(AppTheme.sp20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '学習カレンダー',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp16),

            // Month Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left_rounded, size: 20, color: AppTheme.textPrimary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.elevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.sp16, vertical: AppTheme.sp8),
                  decoration: AppTheme.cardDecoration(color: AppTheme.elevated, radius: AppTheme.radiusSm),
                  child: Text(
                    '${_currentMonth.year}年 ${_currentMonth.month}月',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textPrimary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.elevated,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp24),

            // Calendar Grid display
            _buildCalendarGrid(words, profile.dailyTarget),
            
            const SizedBox(height: AppTheme.sp24),

            // Summary Bottom
            Container(
              padding: const EdgeInsets.all(AppTheme.sp16),
              decoration: AppTheme.cardDecoration(color: AppTheme.elevated, radius: AppTheme.radiusMd),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '連続学習記録',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.sp4),
                        Text(
                          '${profile.streakDays} 日連続学習中！',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.local_fire_department_rounded, color: AppTheme.warning, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<Word> words, int dailyTarget) {
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    
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
            width: 32,
            child: Center(
              child: Text(
                day,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
    
    rows.add(const SizedBox(height: AppTheme.sp12));

    // Calendar cells
    int currentDay = 1;
    for (int i = 0; i < 6; i++) {
      List<Widget> weekCells = [];
      for (int j = 1; j <= 7; j++) {
        if (i == 0 && j < firstWeekday) {
          weekCells.add(const SizedBox(width: 32, height: 32));
        } else if (currentDay > lastDayOfMonth.day) {
          weekCells.add(const SizedBox(width: 32, height: 32));
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
      rows.add(const SizedBox(height: AppTheme.sp8));
      
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
        bgColor = AppTheme.success.withValues(alpha: 0.5);
        textColor = Colors.white;
      } else {
        bgColor = AppTheme.success.withValues(alpha: 0.2);
        textColor = AppTheme.success;
      }
    }

    if (isToday) {
      border = Border.all(color: AppTheme.primary, width: 1.5);
      if (count == 0) {
        textColor = AppTheme.primary;
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: border,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isToday || count > 0 ? FontWeight.w600 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
