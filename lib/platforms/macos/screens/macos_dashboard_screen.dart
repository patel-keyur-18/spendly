import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/budgets/budget_repository.dart';
import '../../../features/expenses/expense_repository.dart' show currentMonthExpensesProvider, monthBounds;
import '../../../features/home/dashboard_providers.dart';
import '../../../features/home/widgets/spend_donut.dart';
import '../../../features/home/widgets/trend_bars.dart';
import '../../../features/ledger/account_balance_provider.dart';
import '../../../features/ledger/ledger_repository.dart';
import '../macos_nav.dart';
import '../macos_tab.dart';
import '../widgets/macos_calendar_heatmap.dart';
import '../widgets/macos_expense_row.dart';

/// Read-only dashboard — same underlying providers and chart widgets as the
/// mobile Home screen (`features/home/home_screen.dart`), just laid out for
/// a desktop window: a 4-across stat row instead of a full-width hero, then
/// donut/trend/recent in a grid instead of stacked full-width.
///
/// [SpendDonut] and [TrendBars] are dropped in unmodified — they're already
/// provider-driven, self-contained, and platform-agnostic (fl_chart has no
/// native dependency), so there is nothing macOS-specific to build for them.
class MacosDashboardScreen extends ConsumerWidget {
  const MacosDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthTotal = ref.watch(monthTotalProvider);
    final budget = effectiveOverallBudget(
      ref.watch(overallBudgetProvider).value,
      ref.watch(perCategoryBudgetsProvider),
      ignoredCategoryIds(ref.watch(categoriesByIdProvider)),
    );
    final hasBudget = budget != null && budget.minor > 0;
    final ratio = hasBudget ? monthTotal.ratioOf(budget).clamp(0.0, 1.0) : 0.0;
    final pct = hasBudget ? (monthTotal.ratioOf(budget) * 100).round() : 0;

    final totalSavings = ref.watch(totalBalanceProvider);
    final income = ref
            .watch(incomeTotalByRangeProvider(monthBounds(DateTime.now())))
            .value ??
        Money.zero;
    final dayOfMonth = DateTime.now().day;
    final avgDaily = Money.fromMinor((monthTotal.minor / dayOfMonth).round());

    final recent = ref.watch(recentExpensesProvider);
    final currentMonthExpenses = ref.watch(currentMonthExpensesProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _HeroMiniTile(
                  spent: monthTotal,
                  budget: budget,
                  hasBudget: hasBudget,
                  ratio: ratio,
                  pct: pct,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StatTile(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: AppColors.green,
                  iconBg: AppColors.green.withValues(alpha: 0.13),
                  value: totalSavings.format(locale: 'en_IN'),
                  caption: 'Total savings across accounts',
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StatTile(
                  icon: Icons.currency_rupee_rounded,
                  iconColor: AppColors.tealDeep,
                  iconBg: AppColors.teal.withValues(alpha: 0.14),
                  value: income.format(locale: 'en_IN'),
                  caption: 'Income this month',
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _StatTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primary.withValues(alpha: 0.13),
                  value: '${avgDaily.format(locale: 'en_IN')}/day',
                  caption: 'Average daily spend',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SpendDonut is mobile's shared widget (features/home/widgets/) —
            // its inner chart+legend layout is a fixed-width row that only
            // fits alongside one sibling, not two, so it keeps this row to
            // itself with TrendBars; the heatmap gets its own row below
            // rather than squeezing a third card in here.
            Expanded(child: _CardWrap('Where it went', const SpendDonut())),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _CardWrap('6-month trend', const TrendBars())),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _CardWrap(
          'Daily spend this month',
          MacosCalendarHeatmap(expenses: currentMonthExpenses, month: DateTime.now()),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent transactions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  TextButton(
                    onPressed: () => MacosNav.of(context).goTo(MacosTab.transactions),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No expenses yet on this Mac — sync from your iPhone first.'),
                )
              else
                for (final (expense, category) in recent)
                  MacosExpenseRow(expense: expense, category: category, trailingDate: true),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        child,
      ],
    );
  }
}

class _HeroMiniTile extends StatelessWidget {
  const _HeroMiniTile({
    required this.spent,
    required this.budget,
    required this.hasBudget,
    required this.ratio,
    required this.pct,
  });
  final Money spent;
  final Money? budget;
  final bool hasBudget;
  final double ratio;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SPENT THIS MONTH', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text(
            spent.format(locale: 'en_IN'),
            style: const TextStyle(fontFamily: 'Sora', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: hasBudget ? ratio : 0,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasBudget ? 'of ${budget!.format(locale: 'en_IN')} · $pct% used' : 'No monthly budget set',
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.caption,
  });
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(fontSize: 11, color: palette.textDim)),
        ],
      ),
    );
  }
}
