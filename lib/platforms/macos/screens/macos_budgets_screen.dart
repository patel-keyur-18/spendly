import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart' show CategoryRow, monthKeyFor;
import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_glyph.dart';
import '../../../features/budgets/budget_repository.dart';
import '../../../features/home/dashboard_providers.dart' show categoriesByIdProvider, ignoredCategoryIds;

/// Read-only budget status — reuses `effectiveOverallBudget` and the same
/// three-tier status split (on track / near limit / over) the mobile app's
/// threshold notifications (80%/100%) are built around, just rendered as a
/// pill instead of a push notification.
class MacosBudgetsScreen extends ConsumerWidget {
  const MacosBudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthKey = monthKeyFor(DateTime.now());
    final byId = ref.watch(categoriesByIdProvider);
    final ignored = ignoredCategoryIds(byId);
    final perCategoryBudgets = ref.watch(perCategoryBudgetsForMonthProvider(monthKey));
    final overall = effectiveOverallBudget(
      ref.watch(overallBudgetForMonthProvider(monthKey)).value,
      perCategoryBudgets,
      ignored,
    );
    final spend = ref.watch(categorySpendForMonthProvider(monthKey)).value ?? const {};
    final spentTotal = spend.entries.where((e) => !ignored.contains(e.key)).fold(Money.zero, (s, e) => s + e.value);

    final hasOverall = overall != null && overall.minor > 0;
    final overallPct = hasOverall ? (spentTotal.ratioOf(overall) * 100).round() : 0;
    final overallStatus = _statusOf(spentTotal, overall);

    final rows = perCategoryBudgets.entries.where((e) => byId[e.key] != null).toList()
      ..sort((a, b) => byId[a.key]!.name.compareTo(byId[b.key]!.name));

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        if (hasOverall)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Overall — ${DateFormat.MMMM().format(DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    _StatusPill(status: overallStatus),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(spentTotal.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 20)),
                    Text('of ${overall.format(locale: 'en_IN')} · $overallPct% used', style: TextStyle(fontSize: 12, color: Theme.of(context).extension<AppPalette>()!.textDim)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: spentTotal.ratioOf(overall).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Theme.of(context).extension<AppPalette>()!.card2,
                    valueColor: AlwaysStoppedAnimation(_statusColor(overallStatus)),
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Text(
              'No overall budget set for this month.',
              style: TextStyle(color: Theme.of(context).extension<AppPalette>()!.textDim),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (rows.isEmpty)
          const SizedBox.shrink()
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _BudgetRow(
                    category: byId[rows[i].key]!,
                    budget: rows[i].value,
                    spent: spend[rows[i].key] ?? Money.zero,
                    showDivider: i > 0,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  _BudgetStatus _statusOf(Money spent, Money? budget) {
    if (budget == null || budget.minor <= 0) return _BudgetStatus.none;
    final pct = spent.ratioOf(budget) * 100;
    if (pct >= 100) return _BudgetStatus.over;
    if (pct >= 80) return _BudgetStatus.near;
    return _BudgetStatus.onTrack;
  }

  Color _statusColor(_BudgetStatus s) => switch (s) {
        _BudgetStatus.over => AppColors.red,
        _BudgetStatus.near => AppColors.accent,
        _BudgetStatus.onTrack => AppColors.green,
        _BudgetStatus.none => AppColors.primary,
      };
}

enum _BudgetStatus { onTrack, near, over, none }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final _BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      _BudgetStatus.over => (AppColors.red, 'Over'),
      _BudgetStatus.near => (AppColors.amberDeep, 'Near limit'),
      _BudgetStatus.onTrack => (AppColors.green, 'On track'),
      _BudgetStatus.none => (Theme.of(context).extension<AppPalette>()!.textDim, 'No budget'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.category, required this.budget, required this.spent, required this.showDivider});
  final CategoryRow category;
  final Money budget;
  final Money spent;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final pct = spent.ratioOf(budget);
    final status = pct >= 1.0
        ? _BudgetStatus.over
        : pct >= 0.8
            ? _BudgetStatus.near
            : _BudgetStatus.onTrack;
    final color = switch (status) {
      _BudgetStatus.over => AppColors.red,
      _BudgetStatus.near => AppColors.accent,
      _BudgetStatus.onTrack => AppColors.green,
      _BudgetStatus.none => AppColors.primary,
    };

    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: palette.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(9)),
                        alignment: Alignment.center,
                        child: CategoryGlyph(category.icon, size: 13),
                      ),
                      const SizedBox(width: 10),
                      Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                  _StatusPill(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${spent.format(locale: 'en_IN')} of ${budget.format(locale: 'en_IN')}', style: TextStyle(fontSize: 12, color: palette.textDim)),
                  Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 12, color: palette.textDim)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: palette.card2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
