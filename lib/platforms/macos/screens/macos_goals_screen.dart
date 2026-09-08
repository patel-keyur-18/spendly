import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/row_extensions.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/goals/goal_repository.dart';

/// Read-only savings goals — [SavingsGoalRow.saved]/[target]/[progressRatio]
/// are all extension getters already defined on the row
/// (`core/db/row_extensions.dart`), so no new math lives here.
class MacosGoalsScreen extends ConsumerWidget {
  const MacosGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalsProvider).value ?? const [];
    final palette = Theme.of(context).extension<AppPalette>()!;

    if (goals.isEmpty) {
      return Center(
        child: Text('No savings goals yet — sync from your iPhone first.', style: TextStyle(color: palette.textDim)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 440,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 2.6,
      ),
      itemCount: goals.length,
      itemBuilder: (context, i) => _GoalCard(goal: goals[i]),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final SavingsGoalRow goal;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return AppCard(
      child: Row(
        children: [
          _ProgressRing(ratio: goal.progressRatio, complete: goal.isComplete),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 15),
                    children: [
                      TextSpan(text: goal.saved.format(locale: 'en_IN')),
                      TextSpan(
                        text: ' of ${goal.target.format(locale: 'en_IN')}',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 12, color: palette.textDim),
                      ),
                    ],
                  ),
                ),
                if (goal.isComplete) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 13, color: AppColors.green),
                      const SizedBox(width: 4),
                      Text('Goal reached', style: TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.ratio, required this.complete});
  final double ratio;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    final color = complete ? AppColors.green : AppColors.primary;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(56, 56),
            painter: _RingPainter(ratio: ratio, track: palette.card2, color: color),
          ),
          Text('${(ratio * 100).round()}%', style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ratio, required this.track, required this.color});
  final double ratio;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.ratio != ratio || oldDelegate.color != color;
}
