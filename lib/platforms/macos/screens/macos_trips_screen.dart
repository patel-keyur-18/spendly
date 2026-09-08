import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/expenses/expense_repository.dart' show tagExpenseCountProvider, tagTotalsProvider;
import '../../../features/tags/tag_repository.dart';

/// Read-only trips/tags — reuses `tagTotalsProvider` (lifetime spend per
/// tag) and `tagExpenseCountProvider` (per-tag entry count), the same two
/// providers the mobile Tags report screen is built on.
class MacosTripsScreen extends ConsumerWidget {
  const MacosTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(activeTagsProvider).value ?? const [];
    final totals = ref.watch(tagTotalsProvider).value ?? const {};
    final palette = Theme.of(context).extension<AppPalette>()!;

    if (tags.isEmpty) {
      return Center(
        child: Text('No tags or trips yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.35,
      ),
      itemCount: tags.length,
      itemBuilder: (context, i) => _TripCard(tag: tags[i], total: totals[tags[i].id] ?? Money.zero),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.tag, required this.total});
  final TagRow tag;
  final Money total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final count = ref.watch(tagExpenseCountProvider(tag.id)).value ?? 0;
    final color = Color(tag.colorValue);
    final range = tag.tripStartDate != null && tag.tripEndDate != null
        ? '${DateFormat.MMMd().format(tag.tripStartDate!)} – ${DateFormat.MMMd().format(tag.tripEndDate!)}'
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tag.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (range != null) Text(range, style: TextStyle(fontSize: 11.5, color: palette.textDim)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: palette.card2, border: Border.all(color: palette.line), borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: Text('$count ${count == 1 ? 'entry' : 'entries'}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textDim)),
              ),
            ],
          ),
          const Spacer(),
          Text(total.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: 1, minHeight: 6, backgroundColor: palette.card2, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }
}
