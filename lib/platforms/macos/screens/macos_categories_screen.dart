import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show monthKeyFor;
import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_glyph.dart';
import '../../../features/budgets/budget_repository.dart' show categorySpendForMonthProvider;
import '../../../features/categories/category_repository.dart';

/// Read-only category grid — this month's spend per category, reusing
/// `categorySpendForMonthProvider` (already keyed by month, already live).
class MacosCategoriesScreen extends ConsumerWidget {
  const MacosCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(activeCategoriesProvider).value ?? const [];
    final spend = ref.watch(categorySpendForMonthProvider(monthKeyFor(DateTime.now()))).value ?? const {};
    final palette = Theme.of(context).extension<AppPalette>()!;

    if (categories.isEmpty) {
      return Center(
        child: Text('No categories yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      // A fixed mainAxisExtent (not childAspectRatio) so cell height never
      // shrinks with window width — the card's content height (icon + two
      // text lines) is fixed regardless of how narrow the window gets, and
      // aspect-ratio-based sizing overflowed by a few pixels once the window
      // was narrow enough to force extra columns.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 118,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        final total = spend[c.id] ?? Money.zero;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.line),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: CategoryGlyph(c.icon, size: 18),
              ),
              const Spacer(),
              Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${total.format(locale: 'en_IN')} this month', style: TextStyle(fontSize: 11.5, color: palette.textDim)),
            ],
          ),
        );
      },
    );
  }
}
