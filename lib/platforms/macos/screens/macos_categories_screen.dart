import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/row_extensions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/category_glyph.dart';
import '../../../features/categories/category_repository.dart';
import '../../../features/home/dashboard_providers.dart';
import '../widgets/macos_treemap.dart' show squarify;

/// Share mosaic — every category with spend this month laid out by the same
/// squarified-treemap algorithm as the Insights screen's treemap
/// (`macos_treemap.dart`'s `squarify`), just full-page instead of one card:
/// tile area is proportional to spend share, so the month composes itself
/// as one field rather than a uniform icon-grid. Categories with no spend
/// this month (not part of `categoryBreakdownProvider`'s slices) list below
/// as plain chips instead of being force-fit into the mosaic at zero size.
class MacosCategoriesScreen extends ConsumerWidget {
  const MacosCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final categories = ref.watch(activeCategoriesProvider).value ?? const [];
    final slices = ref.watch(categoryBreakdownProvider);
    final total = ref.watch(monthTotalProvider);

    if (categories.isEmpty) {
      return Center(
        child: Text('No categories yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
      );
    }

    final spentIds = {for (final s in slices) s.$1.id};
    final noSpend = categories.where((c) => !spentIds.contains(c.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Categories — ${DateFormat('MMMM').format(DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text(
              'Total ${total.format(locale: 'en_IN')} across ${slices.length} active categories',
              style: TextStyle(fontSize: 12, color: palette.textDim),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (slices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text('No spending yet this month.', style: TextStyle(color: palette.textDim)),
          )
        else
          SizedBox(
            height: 460,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rects = squarify(slices, Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight));
                return Stack(
                  children: [
                    for (final r in rects)
                      Positioned(
                        left: r.rect.left + 2,
                        top: r.rect.top + 2,
                        width: (r.rect.width - 4).clamp(0, double.infinity),
                        height: (r.rect.height - 4).clamp(0, double.infinity),
                        child: Tooltip(
                          message: '${r.slice.$1.name} — ${r.slice.$2.format(locale: 'en_IN')} (${(r.slice.$3 * 100).round()}%)',
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: r.slice.$1.color, borderRadius: BorderRadius.circular(16)),
                            // Same threshold + FittedBox pattern as the
                            // Insights treemap — fixed pixel thresholds
                            // without FittedBox previously overflowed on a
                            // cell just above the cutoff.
                            child: r.rect.width > 56 && r.rect.height > 40
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CategoryGlyph(r.slice.$1.icon, size: 20),
                                        const SizedBox(height: 8),
                                        Text(
                                          r.slice.$1.name,
                                          maxLines: 1,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                        Text(
                                          r.slice.$2.format(locale: 'en_IN'),
                                          maxLines: 1,
                                          style: const TextStyle(fontFamily: 'Sora', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        if (noSpend.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'NO SPEND YET THIS MONTH',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: palette.textDim),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in noSpend)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.card,
                    border: Border.all(color: palette.line),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CategoryGlyph(c.icon, size: 14),
                      const SizedBox(width: 6),
                      Text(c.name, style: TextStyle(fontSize: 12, color: palette.textDim)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
