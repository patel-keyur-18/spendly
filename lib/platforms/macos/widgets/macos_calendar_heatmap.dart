import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';

/// Daily spend for [month], bucketed client-side from an already-fetched
/// expense list — same pattern as `dashboard_providers.dart`'s
/// `trendBuckets` (which buckets the same kind of list by month instead of
/// by day). No new repository query: [expenses] is whatever the caller
/// already watched (the dashboard passes its own current-month list).
Map<int, Money> dailyTotals(List<ExpenseRow> expenses, DateTime month) {
  final totals = <int, Money>{};
  for (final e in expenses) {
    if (e.date.year != month.year || e.date.month != month.month) continue;
    totals[e.date.day] = (totals[e.date.day] ?? Money.zero) + e.amount;
  }
  return totals;
}

/// Provider-free calendar heatmap — a grid of day cells for [month], each
/// tinted by that day's spend relative to the month's busiest day. Monday-
/// first, matching the app's INR/Indian-locale convention.
class MacosCalendarHeatmap extends StatelessWidget {
  const MacosCalendarHeatmap({super.key, required this.expenses, required this.month});

  final List<ExpenseRow> expenses;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final totals = dailyTotals(expenses, month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final maxTotal = totals.values.fold(0, (m, v) => v.minor > m ? v.minor : m);
    // Dart's DateTime.weekday is 1=Mon..7=Sun already — Monday-first needs no
    // remapping, just a 0-based column index.
    final firstWeekdayCol = DateTime(month.year, month.month, 1).weekday - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        const gap = 4.0;
        // Capped rather than stretched to the card's full width — a
        // calendar of day cells reads as a compact grid, not seven giant
        // tiles just because the card happens to be wide.
        final cell = ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(0.0, 30.0);
        final rows = ((daysInMonth + firstWeekdayCol) / cols).ceil();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: cols * cell + (cols - 1) * gap,
              height: rows * cell + (rows - 1) * gap,
              child: Stack(
                children: [
                  for (var day = 1; day <= daysInMonth; day++)
                    Builder(builder: (context) {
                      final pos = day - 1 + firstWeekdayCol;
                      final col = pos % cols;
                      final row = pos ~/ cols;
                      final amount = totals[day];
                      final t = (maxTotal == 0 || amount == null) ? 0.0 : amount.minor / maxTotal;
                      final label = DateFormat('MMM d').format(DateTime(month.year, month.month, day));
                      return Positioned(
                        left: col * (cell + gap),
                        top: row * (cell + gap),
                        width: cell,
                        height: cell,
                        child: Tooltip(
                          message: amount == null ? '$label — no spend' : '$label — ${amount.format(locale: 'en_IN')}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: t == 0 ? palette.card2 : Color.lerp(palette.card2, AppColors.primary, t)!,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Less', style: TextStyle(fontSize: 10, color: palette.textDim)),
                const SizedBox(width: 6),
                for (final t in const [0.0, 0.25, 0.5, 0.75, 1.0]) ...[
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: t == 0 ? palette.card2 : Color.lerp(palette.card2, AppColors.primary, t),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
                Text('More', style: TextStyle(fontSize: 10, color: palette.textDim)),
              ],
            ),
          ],
        );
      },
    );
  }
}
