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

/// Risk console — a fixed summary rail (the one number that matters) next
/// to a bar-chart comparison sorted purely by risk (highest % used first),
/// built for a fast "is anything about to blow" scan rather than an
/// alphabetical browse. Same `effectiveOverallBudget`/threshold math as
/// mobile's push-notification thresholds (80%/100%); just laid out
/// differently.
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
    final overallRatio = hasOverall ? spentTotal.ratioOf(overall).clamp(0.0, 1.0) : 0.0;
    final overallPct = hasOverall ? (spentTotal.ratioOf(overall) * 100).round() : 0;
    final overallStatus = _statusOf(spentTotal, overall);

    final rows = perCategoryBudgets.entries.where((e) => byId[e.key] != null).map((e) {
      final category = byId[e.key]!;
      final budget = e.value;
      final spentAmt = spend[e.key] ?? Money.zero;
      final ratio = budget.minor <= 0 ? 0.0 : spentAmt.ratioOf(budget);
      return (category: category, budget: budget, spent: spentAmt, ratio: ratio);
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    final overCount = rows.where((r) => r.ratio >= 1.0).length;
    final nearCount = rows.where((r) => r.ratio >= 0.8 && r.ratio < 1.0).length;
    final onTrackCount = rows.where((r) => r.ratio < 0.8).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall — ${DateFormat.MMMM().format(DateTime.now())}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 14),
                    if (hasOverall) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: overallRatio,
                                  strokeWidth: 7,
                                  backgroundColor: Theme.of(context).extension<AppPalette>()!.card2,
                                  valueColor: AlwaysStoppedAnimation(_statusColor(overallStatus)),
                                ),
                                Text('$overallPct%', style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(spentTotal.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 16)),
                                Text(
                                  'of ${overall.format(locale: 'en_IN')}',
                                  style: TextStyle(fontSize: 11, color: Theme.of(context).extension<AppPalette>()!.textDim),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text('No overall budget set.', style: TextStyle(color: Theme.of(context).extension<AppPalette>()!.textDim, fontSize: 12)),
                    const SizedBox(height: 18),
                    Divider(height: 1, color: Theme.of(context).extension<AppPalette>()!.line),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _RailStat(count: overCount, label: 'Over', color: AppColors.red),
                        _RailStat(count: nearCount, label: 'Near', color: AppColors.amberDeep),
                        _RailStat(count: onTrackCount, label: 'On track', color: AppColors.green),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: rows.isEmpty
                  ? AppCard(
                      child: Text(
                        'No per-category budgets set for this month.',
                        style: TextStyle(color: Theme.of(context).extension<AppPalette>()!.textDim),
                      ),
                    )
                  : AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            _RiskRow(
                              category: rows[i].category,
                              budget: rows[i].budget,
                              spent: rows[i].spent,
                              ratio: rows[i].ratio,
                              showDivider: i > 0,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
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
        _BudgetStatus.near => AppColors.amberDeep,
        _BudgetStatus.onTrack => AppColors.green,
        _BudgetStatus.none => AppColors.primary,
      };
}

enum _BudgetStatus { onTrack, near, over, none }

class _RailStat extends StatelessWidget {
  const _RailStat({required this.count, required this.label, required this.color});
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 17, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: palette.textDim)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.category, required this.budget, required this.spent, required this.ratio, required this.showDivider});
  final CategoryRow category;
  final Money budget;
  final Money spent;
  final double ratio;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final status = ratio >= 1.0
        ? _BudgetStatus.over
        : ratio >= 0.8
            ? _BudgetStatus.near
            : _BudgetStatus.onTrack;
    final color = switch (status) {
      _BudgetStatus.over => AppColors.red,
      _BudgetStatus.near => AppColors.amberDeep,
      _BudgetStatus.onTrack => AppColors.green,
      _BudgetStatus.none => AppColors.primary,
    };
    final pct = (ratio * 100).round();

    return Column(
      children: [
        if (showDivider) Divider(height: 1, color: palette.line),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: CategoryGlyph(category.icon, size: 12),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 16,
                    child: Stack(
                      children: [
                        Container(color: palette.card2),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 110,
                child: Text(
                  '$pct% · ${spent.format(locale: 'en_IN')}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11.5, color: palette.textDim),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
