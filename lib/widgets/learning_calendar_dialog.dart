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
    final words = ref.watch(wordListProvider);

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
        constraints: const BoxConstraints(maxWidth: 380),
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
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'RACE LOG',
                          style: GoogleFonts.orbitron(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Month Selector
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '$_year年 $_month月',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
                        onPressed: _nextMonth,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isWeekend ? Colors.redAccent.withOpacity(0.7) : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),

                // Days Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < offset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - offset + 1;
                    final dateStr = "$_year-${_month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
                    
                    // その日にレビュー（学習判定）した単語数をカウント
                    final learnedCount = words.where((w) {
                      if (w.reviewedAt == null) return false;
                      final d = w.reviewedAt!;
                      final dStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
                      return dStr == dateStr;
                    }).length;
                    
                    final now = DateTime.now();
                    final isToday = now.year == _year && now.month == _month && now.day == day;

                    // ヒートマップ（濃淡）のデコレーション決定
                    BoxDecoration boxDecoration;
                    Color textColor = AppTheme.textPrimary;
                    
                    if (learnedCount >= profile.dailyTarget) {
                      // 目標達成（パープル・ベストラップ）
                      boxDecoration = BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A2BE2), AppTheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
                      );
                      textColor = Colors.white;
                    } else if (learnedCount >= 5) {
                      // 中位（グリーン）
                      boxDecoration = BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.withOpacity(0.6),
                        border: isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
                      );
                      textColor = Colors.black87;
                    } else if (learnedCount > 0) {
                      // 少量（薄いグリーン）
                      boxDecoration = BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent.withOpacity(0.22),
                        border: isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
                      );
                      textColor = AppTheme.textPrimary;
                    } else {
                      // 学習なし
                      boxDecoration = BoxDecoration(
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: AppTheme.primary, width: 1.5) : null,
                        color: isToday ? AppTheme.primary.withOpacity(0.15) : Colors.transparent,
                      );
                      textColor = isToday ? AppTheme.primary : AppTheme.textPrimary;
                    }

                    return Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: boxDecoration,
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: (learnedCount > 0 || isToday) ? FontWeight.bold : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Monthly Summary Card (F1 Theme)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
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
                        child: const Icon(Icons.flag_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '今月の走行実績',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '合計 $learnedInMonthCount セッション走破しました',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'STREAK: ${profile.streakDays}日',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
