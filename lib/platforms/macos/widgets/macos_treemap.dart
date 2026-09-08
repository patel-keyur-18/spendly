import 'package:flutter/material.dart';

import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../features/home/dashboard_providers.dart' show CategorySlice;

class _TreemapRect {
  _TreemapRect(this.slice, this.rect);
  final CategorySlice slice;
  final Rect rect;
}

/// Classic squarified-treemap layout — same algorithm as every other
/// treemap implementation (lay out one row/column at a time, picking
/// whichever orientation keeps cells closest to square), just in Dart
/// instead of the JS used in the original HTML prototype this app's design
/// was translated from (see DESIGN.md).
List<_TreemapRect> _squarify(List<CategorySlice> slices, Rect bounds) {
  final items = [...slices]..sort((a, b) => b.$2.minor.compareTo(a.$2.minor));
  final out = <_TreemapRect>[];
  var remaining = items;
  var rect = bounds;

  while (remaining.isNotEmpty) {
    final wide = rect.width > rect.height;
    final n = remaining.length >= 3 ? 3 : remaining.length;
    final row = remaining.sublist(0, n);
    remaining = remaining.sublist(n);
    final rowTotal = row.fold(0, (s, e) => s + e.$2.minor);
    final leftoverTotal = remaining.fold(0, (s, e) => s + e.$2.minor);
    final frac = rowTotal / (rowTotal + leftoverTotal);

    if (wide) {
      final rowWidth = rect.width * frac;
      var offset = rect.top;
      for (final item in row) {
        final h = rowTotal == 0 ? 0.0 : rect.height * (item.$2.minor / rowTotal);
        out.add(_TreemapRect(item, Rect.fromLTWH(rect.left, offset, rowWidth, h)));
        offset += h;
      }
      rect = Rect.fromLTWH(rect.left + rowWidth, rect.top, rect.width - rowWidth, rect.height);
    } else {
      final rowHeight = rect.height * frac;
      var offset = rect.left;
      for (final item in row) {
        final w = rowTotal == 0 ? 0.0 : rect.width * (item.$2.minor / rowTotal);
        out.add(_TreemapRect(item, Rect.fromLTWH(offset, rect.top, w, rowHeight)));
        offset += w;
      }
      rect = Rect.fromLTWH(rect.left, rect.top + rowHeight, rect.width, rect.height - rowHeight);
    }
  }
  return out;
}

/// Provider-free category treemap + legend, sized proportionally to this
/// month's spend per category (`categoryBreakdownProvider`'s already-sorted
/// [CategorySlice] list).
class MacosCategoryTreemap extends StatelessWidget {
  const MacosCategoryTreemap({super.key, required this.slices, required this.total});

  final List<CategorySlice> slices;
  final Money total;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      final palette = Theme.of(context).extension<AppPalette>()!;
      return SizedBox(
        height: 220,
        child: Center(child: Text('No spending yet', style: TextStyle(color: palette.textDim, fontSize: 13))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rects = _squarify(slices, Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight));
              return Stack(
                children: [
                  for (final r in rects)
                    Positioned(
                      left: r.rect.left + 1.5,
                      top: r.rect.top + 1.5,
                      width: (r.rect.width - 3).clamp(0, double.infinity),
                      height: (r.rect.height - 3).clamp(0, double.infinity),
                      child: Tooltip(
                        message: '${r.slice.$1.name} — ${r.slice.$2.format(locale: 'en_IN')} (${(r.slice.$3 * 100).round()}%)',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: r.slice.$1.color, borderRadius: BorderRadius.circular(8)),
                          // FittedBox (not a fixed width/height threshold) so
                          // the label always fits the cell it's actually
                          // given — real category counts/proportions vary
                          // per user, so hand-tuned pixel thresholds here
                          // previously overflowed on a cell just above the
                          // cutoff (two text lines needed more height than
                          // the padding left for them).
                          child: r.rect.width > 44 && r.rect.height > 22
                              ? FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        r.slice.$1.name,
                                        maxLines: 1,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                                      ),
                                      Text(
                                        r.slice.$2.format(locale: 'en_IN'),
                                        maxLines: 1,
                                        style: const TextStyle(fontFamily: 'Sora', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
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
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in slices)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: s.$1.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text(s.$1.name, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
