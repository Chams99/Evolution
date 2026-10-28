import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../lab_controller.dart';
import '../theme.dart';
import 'charts.dart';

/// One card per trait under the view: where it is, how far it has moved since
/// the start (dotted line), whether selection is pushing it right now, and its trend.
class TraitStrip extends StatelessWidget {
  const TraitStrip({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.samples,
      builder: (context, _, _) => Row(
        children: [
          for (final (i, trait) in Trait.values.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _TraitCard(trait: trait, controller: controller),
            ),
          ],
        ],
      ),
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({required this.trait, required this.controller});

  final Trait trait;
  final LabController controller;

  static const _threshold = 0.2;

  @override
  Widget build(BuildContext context) {
    final history = controller.world.history;
    final color = Palette.trait(trait);
    final now = history.last.traits[trait]!;
    final start = history.first.traits[trait]!;
    final change = start.mean == 0 ? 0.0 : now.mean / start.mean - 1;
    final digits = trait == Trait.sense ? 0 : 2;
    final s = controller.selectionOf(trait);
    final (IconData? arrow, verdict, verdictColor) = s == null
        ? (null, 'measuring…', Palette.faint)
        : s > _threshold
        ? (Icons.arrow_upward, 'favoured', color)
        : s < -_threshold
        ? (Icons.arrow_downward, 'selected against', color)
        : (null, 'neutral', Palette.faint);
    final extinct = controller.world.extinct;

    final name = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Palette.traitIcon(trait), size: 13, color: color),
        const SizedBox(width: 6),
        Text(trait.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(extinct ? '—' : now.mean.toStringAsFixed(digits), style: Styles.readout.copyWith(fontSize: 17)),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '${change >= 0 ? '+' : ''}${(change * 100).round()}%',
            style: Styles.readout.copyWith(fontSize: 11.5, color: change.abs() < 0.05 ? Palette.faint : Palette.cream),
          ),
        ),
      ],
    );
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            extinct ? '' : verdict,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: verdictColor),
          ),
        ),
        if (arrow != null && !extinct) ...[const SizedBox(width: 2), Icon(arrow, size: 12, color: verdictColor)],
      ],
    );
    final chart = TraitChart(
      samples: history,
      trait: trait,
      range: controller.config.limits.of(trait),
      height: 34,
      trendOnly: true,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 300) {
            return Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [name, const SizedBox(height: 4), value],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [badge, const SizedBox(height: 4), chart],
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(child: name),
                  if (arrow != null && !extinct) ...[const Spacer(), Icon(arrow, size: 13, color: verdictColor)],
                ],
              ),
              const SizedBox(height: 4),
              value,
              const SizedBox(height: 2),
              chart,
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  extinct ? '' : verdict,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: verdictColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
