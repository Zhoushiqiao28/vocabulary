import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class LearningCalendarDialog extends ConsumerStatefulWidget {
  const LearningCalendarDialog({super.key});

  @override
  ConsumerState<LearningCalendarDialog> createState() => _LearningCalendarDialogState();
}

class _LearningCalendarDialogState extends ConsumerState<LearningCalendarDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final learnedDates = profile.learnedDates;

    // Days in current month
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    // Weekday of 1st day of the month (1 = Monday, 7 = Sunday)
    final firstDayWeekday = DateTime(_year, _month, 1).weekday;
    
    // We start week on Monday
    final offset = firstDayWeekday - 1;
    final totalCells = offset + daysInMonth;

    // Count learned days in this month
    int learnedInMonthCount = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      final dateStr = "$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
      if (learnedDates.contains(dateStr)) {
        learnedInMonthCount++;
      }
    }

    final weekDays = ['月', '火', '水', '木', '金', '土', '日'];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 5,
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📅 学習履歴カレンダー',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Month Selector
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primary),
                        onPressed: _prevMonth,
                      ),
                      Text(
                        '$_year年 $_month月',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekday Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weekDays.map((day) {
                    final isWeekend = day == '土' || day == '日';
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isWeekend ? Colors.redAccent.withOpacity(0.7) : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Days Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < offset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - offset + 1;
                    final dateStr = "$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
                    final isLearned = learnedDates.contains(dateStr);
                    
                    final now = DateTime.now();
                    final isToday = now.year == _year && now.month == _month && now.day == day;

                    return Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isLearned
                              ? const LinearGradient(
                                  colors: [Colors.teal, Colors.tealAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: isToday
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                          color: !isLearned && isToday
                              ? AppTheme.primary.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: (isLearned || isToday) ? FontWeight.bold : FontWeight.normal,
                              color: isLearned
                                  ? Colors.black87
                                  : (isToday ? AppTheme.primary : AppTheme.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Monthly Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今月の学習実績',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '合計 $learnedInMonthCount 日学習しました',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '継続中: ${profile.streakDays}日',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
