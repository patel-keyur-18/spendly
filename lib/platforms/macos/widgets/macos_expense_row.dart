import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/db/row_extensions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_glyph.dart';
import '../../../features/expenses/widgets/expense_tile.dart' show relativeDayLabel;

/// Read-only expense row — deliberately not a reuse of
/// `features/expenses/widgets/expense_tile.dart`'s `ExpenseTile`, which is
/// swipe-to-delete and tap-to-edit. Nothing on the macOS build is allowed to
/// write to the database outside the Sync screen, so this is a plain,
/// non-interactive presentation of the same row shape (category glyph,
/// title, relative time, amount), reusing only the pure pieces
/// (`relativeDayLabel`, `CategoryGlyph`, `row.amount`/`row.color`).
class MacosExpenseRow extends StatelessWidget {
  const MacosExpenseRow({
    super.key,
    required this.expense,
    required this.category,
    this.selected = false,
    this.trailingDate = false,
    this.onTap,
  });

  final ExpenseRow expense;
  final CategoryRow? category;
  final bool selected;

  /// Shows a short date on the right instead of nothing — used by the
  /// dashboard's "Recent" list, which isn't grouped by day like the
  /// Transactions screen is.
  final bool trailingDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final title = expense.note?.isNotEmpty == true
        ? expense.note!
        : (category?.name ?? 'Expense');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (category?.color ?? palette.textDim).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.icon),
              ),
              alignment: Alignment.center,
              child: CategoryGlyph(category?.icon ?? '💸', size: 16),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    category?.name ?? 'Uncategorized',
                    style: TextStyle(fontSize: 11.5, color: palette.textDim),
                  ),
                ],
              ),
            ),
            Text(
              '-${expense.amount.format(locale: 'en_IN')}',
              style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            if (trailingDate) ...[
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 56,
                child: Text(
                  DateFormat.MMMd().format(expense.date),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: palette.textDim),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// relativeDayLabel re-exported for screens that need the day-group header
// text without pulling in the rest of all_transactions_screen.dart.
String macosRelativeDayLabel(DateTime d) => relativeDayLabel(d);
