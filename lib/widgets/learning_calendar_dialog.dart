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
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.borderColor),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
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
                  'MATRIX_LED_CALENDAR // DICTIONARY_LOG',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),

            // Month Selector (styled as tactile toggle block)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TactileButton(
                  width: 38,
                  height: 32,
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                  child: const Icon(Icons.chevron_left_rounded, size: 16, color: AppTheme.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: AppTheme.displayDecoration(glow: false),
                  child: Text(
                    '${_currentMonth.year} // ${_currentMonth.month.toString().padLeft(2, '0')}',
                    style: GoogleFonts.shareTechMono(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                TactileButton(
                  width: 38,
                  height: 32,
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                    });
                  },
                  child: const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar Grid display
            _buildCalendarGrid(words, profile.dailyTarget),
            
            const SizedBox(height: 20),

            // Summary Bottom (VFD streak details)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.displayDecoration(glow: false),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONTINUITY STREAK READOUT',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'STREAK: ${profile.streakDays.toString().padLeft(2, '0')} DAYS ACTIVE',
                          style: GoogleFonts.shareTechMono(
                            fontSize: 14,
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
                style: GoogleFonts.shareTechMono(
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
    Color ledColor = AppTheme.success.withOpacity(0.04);
    Color textColor = AppTheme.textSecondary;
    Border? border;
    List<BoxShadow>? shadows;
    
    if (count > 0) {
      if (count >= dailyTarget) {
        ledColor = AppTheme.success;
        textColor = AppTheme.displayBg;
        shadows = [
          BoxShadow(
            color: AppTheme.success.withOpacity(0.6),
            blurRadius: 4,
            spreadRadius: 0.5,
          )
        ];
      } else if (count >= dailyTarget / 2) {
        ledColor = AppTheme.success.withOpacity(0.5);
        textColor = AppTheme.textPrimary;
      } else {
        ledColor = AppTheme.success.withOpacity(0.2);
        textColor = AppTheme.success;
      }
    }

    if (isToday) {
      border = Border.all(color: AppTheme.primary, width: 1.0);
      if (count == 0) {
        textColor = AppTheme.primary;
      }
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: ledColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: border,
        boxShadow: shadows,
      ),
      child: Center(
        child: Text(
          day.toString().padLeft(2, '0'),
          style: GoogleFonts.shareTechMono(
            fontSize: 10,
            fontWeight: isToday || count > 0 ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
