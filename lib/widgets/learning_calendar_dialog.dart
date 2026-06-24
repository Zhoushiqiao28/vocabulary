import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../providers/providers.dart';

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
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF141414), // Dark brutalist bg
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          // No border radius
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVITY',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Month Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                    });
                  },
                ),
                Text(
                  '${_currentMonth.year} / ${_currentMonth.month.toString().padLeft(2, '0')}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
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
            
            const SizedBox(height: 32),

            // Summary Bottom (Sharp edges)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white.withOpacity(0.02),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT STREAK',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${profile.streakDays} DAYS',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE10600),
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
    // Weekday headers
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    // Calculate days in month
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // 1=Monday, 7=Sunday
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Group reviewed words by day
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
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
    
    rows.add(const SizedBox(height: 12));

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
          
          weekCells.add(_buildDayCell(currentDay, count, dailyTarget, isToday, j >= 6));
          currentDay++;
        }
      }
      
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekCells,
        ),
      );
      rows.add(const SizedBox(height: 8));
      
      if (currentDay > lastDayOfMonth.day) break;
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(int day, int count, int dailyTarget, bool isToday, bool isWeekend) {
    Color bgColor = Colors.transparent;
    Color textColor = isWeekend ? const Color(0xFFF87171).withOpacity(0.7) : Colors.white70;
    
    if (count > 0) {
      if (count >= dailyTarget) {
        bgColor = const Color(0xFFE10600); // Target achieved: Primary red
        textColor = Colors.white;
      } else if (count >= dailyTarget / 2) {
        bgColor = Colors.white.withOpacity(0.2);
        textColor = Colors.white;
      } else {
        bgColor = Colors.white.withOpacity(0.05);
        textColor = Colors.white;
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        // No border radius, sharp boxes
        border: isToday
            ? Border.all(color: Colors.white, width: 1)
            : null,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isToday || count > 0 ? FontWeight.w700 : FontWeight.w400,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
