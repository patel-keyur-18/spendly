import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/expenses/expense_repository.dart' show currentMonthExpensesProvider, monthBounds;
import '../../../features/home/dashboard_providers.dart';
import '../../../features/ledger/ledger_repository.dart';
import '../widgets/macos_expense_row.dart';
import '../widgets/macos_income_flow.dart';
import '../widgets/macos_treemap.dart';

/// Desktop-only visuals with no mobile equivalent — the treemap and income
/// flow both consume [categoryBreakdownProvider], the exact same
/// [CategorySlice] list `SpendDonut` already renders on Dashboard, just
/// drawn two different ways for the extra screen space a desktop window
/// affords.
class MacosInsightsScreen extends ConsumerWidget {
  const MacosInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slices = ref.watch(categoryBreakdownProvider);
    final monthTotal = ref.watch(monthTotalProvider);
    final income = ref.watch(incomeTotalByRangeProvider(monthBounds(DateTime.now()))).value ?? Money.zero;
    final trend = ref.watch(trendProvider);

    final currentExpenses = ref.watch(currentMonthExpensesProvider).value ?? const [];
    final byId = ref.watch(categoriesByIdProvider);
    final largest = [...currentExpenses]..sort((a, b) => b.amount.minor.compareTo(a.amount.minor));

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CardWrap(
                'Category treemap — proportion of spend',
                MacosCategoryTreemap(slices: slices, total: monthTotal),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _CardWrap(
                'Where income goes',
                MacosIncomeFlow(income: income, spent: monthTotal, slices: slices),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Largest expenses this month', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (largest.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No expenses this month.'))
                    else
                      for (final e in largest.take(5))
                        MacosExpenseRow(expense: e, category: byId[e.categoryId], trailingDate: true),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _MonthComparisonCard(trend: trend)),
          ],
        ),
      ],
    );
  }
}

class _CardWrap extends StatelessWidget {
  const _CardWrap(this.title, this.child);
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  const _MonthComparisonCard({required this.trend});
  final List<TrendBar> trend;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    if (trend.length < 2) {
      return AppCard(child: Text('Not enough history yet.', style: TextStyle(color: palette.textDim)));
    }
    final thisMonth = trend.last;
    final lastMonth = trend[trend.length - 2];
    final delta = thisMonth.$2.minor - lastMonth.$2.minor;
    final pct = lastMonth.$2.minor == 0 ? null : (delta / lastMonth.$2.minor * 100);
    final up = delta > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This month vs last month', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lastMonth.$1, style: TextStyle(fontSize: 11, color: palette.textDim)),
                    Text(lastMonth.$2.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: palette.textDim),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(thisMonth.$1, style: TextStyle(fontSize: 11, color: palette.textDim)),
                    Text(thisMonth.$2.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (pct != null)
            Row(
              children: [
                Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: up ? AppColors.red : AppColors.green),
                const SizedBox(width: 6),
                Text(
                  '${up ? '+' : ''}${pct.toStringAsFixed(0)}% ${up ? 'more' : 'less'} than last month',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: up ? AppColors.red : AppColors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
