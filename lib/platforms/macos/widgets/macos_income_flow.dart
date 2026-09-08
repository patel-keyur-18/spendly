import 'package:flutter/material.dart';

import '../../../core/db/row_extensions.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../features/home/dashboard_providers.dart' show CategorySlice;

class _Ribbon {
  _Ribbon(this.x1, this.y1, this.h1, this.x2, this.y2, this.h2, this.color, this.opacity);
  final double x1, y1, h1, x2, y2, h2;
  final Color color;
  final double opacity;
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.ribbons);
  final List<_Ribbon> ribbons;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in ribbons) {
      final mx = (r.x1 + r.x2) / 2;
      final path = Path()
        ..moveTo(r.x1, r.y1)
        ..cubicTo(mx, r.y1, mx, r.y2, r.x2, r.y2)
        ..lineTo(r.x2, r.y2 + r.h2)
        ..cubicTo(mx, r.y2 + r.h2, mx, r.y1 + r.h1, r.x1, r.y1 + r.h1)
        ..close();
      canvas.drawPath(path, Paint()..color = r.color.withValues(alpha: r.opacity));
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => oldDelegate.ribbons != ribbons;
}

/// Provider-free income → spent/saved → category flow. Three columns:
/// income splits into spent and saved, spent splits further into each
/// category's share (the same [CategorySlice] list the treemap and donut
/// both already consume).
class MacosIncomeFlow extends StatelessWidget {
  const MacosIncomeFlow({
    super.key,
    required this.income,
    required this.spent,
    required this.slices,
  });

  final Money income;
  final Money spent;
  final List<CategorySlice> slices;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    if (income.minor <= 0) {
      return SizedBox(
        height: 240,
        child: Center(child: Text('No income logged yet', style: TextStyle(color: palette.textDim, fontSize: 13))),
      );
    }
    final overspent = spent.minor > income.minor;
    final saved = overspent ? Money.zero : income - spent;
    final cappedSpent = overspent ? income : spent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight - 20;
              const nodeW = 14.0;
              final col0x = 0.0;
              final col1x = w * 0.34;
              final col2x = w * 0.7;
              final scale = h / income.minor;

              final incomeH = h;
              final spentH = cappedSpent.minor * scale;
              final savedH = saved.minor * scale;

              final ribbons = <_Ribbon>[
                _Ribbon(nodeW, 0, spentH, col1x, 0, spentH, AppColors.primary, 0.28),
                if (saved.minor > 0)
                  _Ribbon(nodeW, spentH, savedH, col1x, spentH, savedH, AppColors.green, 0.28),
              ];
              var y = 0.0;
              final catNodes = <(CategorySlice, double, double)>[]; // slice, y, height
              for (final s in slices) {
                final ch = spentH * s.$3;
                ribbons.add(_Ribbon(col1x + nodeW, y, ch, col2x, y, ch, s.$1.color, 0.85));
                catNodes.add((s, y, ch));
                y += ch;
              }

              return Stack(
                children: [
                  CustomPaint(size: Size(w, h), painter: _RibbonPainter(ribbons)),
                  // Income node
                  Positioned(
                    left: col0x,
                    top: 0,
                    width: nodeW,
                    height: incomeH,
                    child: Container(decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                  ),
                  Positioned(
                    left: col0x + nodeW + 8,
                    top: incomeH / 2 - 14,
                    child: _NodeLabel('Income', income),
                  ),
                  // Spent node
                  Positioned(
                    left: col1x,
                    top: 0,
                    width: nodeW,
                    height: spentH,
                    child: Container(decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4))),
                  ),
                  if (spentH > 24)
                    Positioned(left: col1x + nodeW + 8, top: spentH / 2 - 14, child: _NodeLabel('Spent', cappedSpent)),
                  // Saved node
                  if (saved.minor > 0) ...[
                    Positioned(
                      left: col1x,
                      top: spentH,
                      width: nodeW,
                      height: savedH,
                      child: Container(decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(4))),
                    ),
                    if (savedH > 24)
                      Positioned(left: col1x + nodeW + 8, top: spentH + savedH / 2 - 14, child: _NodeLabel('Saved', saved)),
                  ],
                  // Category nodes
                  for (final (slice, ny, nh) in catNodes)
                    Positioned(
                      left: col2x,
                      top: ny,
                      width: nodeW,
                      height: nh < 1.5 ? 1.5 : nh,
                      child: Tooltip(
                        message: '${slice.$1.name} — ${slice.$2.format(locale: 'en_IN')}',
                        child: Container(decoration: BoxDecoration(color: slice.$1.color, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  for (final (slice, ny, nh) in catNodes)
                    if (nh >= 22)
                      Positioned(
                        left: col2x + nodeW + 7,
                        top: ny + nh / 2 - 9,
                        width: w - (col2x + nodeW + 7),
                        child: Text(
                          slice.$1.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textDim),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
        if (overspent) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.red),
              const SizedBox(width: 6),
              Text('Spending exceeded income this month', style: TextStyle(fontSize: 11, color: AppColors.red)),
            ],
          ),
        ],
        const SizedBox(height: 10),
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

class _NodeLabel extends StatelessWidget {
  const _NodeLabel(this.label, this.amount);
  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.textDim)),
        Text(amount.format(locale: 'en_IN'), style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 11.5)),
      ],
    );
  }
}
