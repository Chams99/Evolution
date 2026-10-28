import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../microbes.dart';
import '../theme.dart';
import 'charts.dart';

/// A titled block in the side panel.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title.toUpperCase(), style: Styles.label),
              const SizedBox(width: 12),
              if (trailing case final trailing?)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Time, population and generation for the current run.
class Readouts extends StatelessWidget {
  const Readouts({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.frame,
      builder: (context, _, _) {
        final world = controller.world;
        Widget item(String label, String value, [Color color = Palette.cream]) => Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: Styles.label.copyWith(fontSize: 10, color: Palette.faint)),
              const SizedBox(height: 2),
              Text(value, style: Styles.readout.copyWith(color: color)),
            ],
          ),
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item('TIME', formatClock(world.seconds)),
            item('MICROBES', '${world.organisms.length}'),
            item('GENERATION', '${world.maxGeneration}'),
            item('LIGHT', '${(world.foodSupply * 100).round()}%', Palette.gold),
          ],
        );
      },
    );
  }
}

class TransportBar extends StatelessWidget {
  const TransportBar({super.key, required this.controller, this.compact = false});

  final LabController controller;

  /// Icon-only secondary buttons, for phones.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final extinct = controller.world.extinct;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: extinct ? null : controller.togglePlaying,
          icon: Icon(controller.playing ? Icons.pause : Icons.play_arrow, size: 18),
          label: Text(controller.playing ? 'Pause' : 'Play'),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.gold,
            foregroundColor: Palette.surface,
            textStyle: const TextStyle(fontFamily: Styles.body, fontWeight: FontWeight.w600, fontSize: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
        ),
        _Outlined(
          label: '+1 s',
          icon: Icons.skip_next,
          compact: compact,
          tooltip: 'Advance one simulated second (right arrow key)',
          onPressed: extinct ? null : controller.stepSecond,
        ),
        _SpeedPicker(controller: controller),
        _Outlined(
          label: 'Restart',
          icon: Icons.replay,
          compact: compact,
          tooltip: 'Same seed, fresh start (R)',
          onPressed: controller.restart,
        ),
        _Outlined(
          label: 'New seed',
          icon: Icons.shuffle,
          compact: compact,
          tooltip: 'Run the same setup with another seed',
          onPressed: controller.reseed,
        ),
      ],
    );
  }
}

class _Outlined extends StatelessWidget {
  const _Outlined({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: Palette.cream,
      side: const BorderSide(color: Palette.lineStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: const TextStyle(fontFamily: Styles.body, fontSize: 13.5),
      padding: compact ? EdgeInsets.zero : null,
      minimumSize: compact ? const Size(40, 40) : null,
    );
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: compact ? label : null,
        child: OutlinedButton(onPressed: onPressed, style: style, child: compact ? Icon(icon, size: 18) : Text(label)),
      ),
    );
  }
}

class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.lineStrong),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in LabController.speeds)
            Semantics(
              button: true,
              selected: controller.speed == s,
              label: 'Speed $s times',
              child: InkWell(
                borderRadius: BorderRadius.circular(3),
                onTap: () => controller.setSpeed(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: controller.speed == s ? Palette.raised : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '$s×',
                    style: Styles.readout.copyWith(
                      fontSize: 12,
                      color: controller.speed == s ? Palette.cream : Palette.faint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Live charts of the run.
class ChartsPanel extends StatelessWidget {
  const ChartsPanel({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.samples,
      builder: (context, _, _) {
        final world = controller.world;
        final history = world.history;
        final latest = history.last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Section(
              title: 'Right now',
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border(left: BorderSide(color: Palette.gold.withValues(alpha: 0.8), width: 2)),
                ),
                child: Text(controller.insight, style: const TextStyle(fontSize: 13.5, height: 1.45)),
              ),
            ),
            Section(
              title: 'Traits',
              trailing: Text(
                'mean ± 1 sd · change since start',
                style: Styles.label.copyWith(fontSize: 10, color: Palette.faint, fontWeight: FontWeight.w400),
              ),
              child: Column(
                children: [
                  for (final trait in Trait.values) _TraitRow(trait: trait, controller: controller),
                  Text(
                    'An up arrow means favoured, a down arrow selected against. Both compare the parents of the '
                    'last 30 seconds of births with the whole population.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Section(
              title: 'Families',
              trailing: Text(
                '${latest.families.length} alive',
                style: Styles.label.copyWith(color: Palette.faint, fontWeight: FontWeight.w400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FamiliesChart(samples: history),
                  const SizedBox(height: 8),
                  Text(
                    'Each band is one founder\'s family, in the colour of its cells. When a band widens, that '
                    'family is out-dividing the rest. Most families vanish; a few take over.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Section(
              title: 'Population',
              trailing: const _Key(items: [('microbes', Palette.cream), ('algae', Palette.food)]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PopulationChart(samples: history),
                  const SizedBox(height: 8),
                  Text(
                    'Last second: ${latest.births} divided, ${latest.starved} starved, '
                    '${latest.diedOfAge} died of age${world.config.predation ? ', ${latest.eaten} engulfed' : ''}'
                    '${latest.struck > 0 ? ', ${latest.struck} killed by UV' : ''}. '
                    'Shading shows the lamp\'s light cycle.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Section(
              title: 'Population map',
              trailing: Text(
                'colour = family · opacity = sense',
                style: Styles.label.copyWith(color: Palette.faint, fontWeight: FontWeight.w400),
              ),
              child: ValueListenableBuilder(
                valueListenable: controller.frame,
                builder: (context, _, _) => TraitScatter(
                  organisms: controller.world.organisms,
                  limits: controller.config.limits,
                  selected: controller.selected,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.trait, required this.controller});

  final Trait trait;
  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final history = controller.world.history;
    final now = history.last.traits[trait]!;
    final start = history.first.traits[trait]!;
    final digits = trait == Trait.sense ? 0 : 2;
    final change = start.mean == 0 ? 0 : (now.mean - start.mean) / start.mean * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Palette.traitIcon(trait), size: 13, color: Palette.gold),
                    const SizedBox(width: 6),
                    Text(trait.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  controller.world.extinct
                      ? '—'
                      : '${now.mean.toStringAsFixed(digits)} ± ${now.deviation.toStringAsFixed(digits)}',
                  style: Styles.readout.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                      style: Styles.label.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: Palette.faint),
                    ),
                    const SizedBox(width: 6),
                    _SelectionBadge(value: controller.selectionOf(trait), color: Palette.trait(trait)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TraitChart(samples: history, trait: trait, range: controller.config.limits.of(trait)),
          ),
        ],
      ),
    );
  }
}

/// Whether a trait is currently favoured, from the smoothed selection reading.
class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.value, required this.color});

  final double? value;
  final Color color;

  static const _threshold = 0.2;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final (IconData icon, tone, tip) = v == null
        ? (Icons.more_horiz, Palette.faint, 'Not enough recent births to measure selection yet')
        : v > _threshold
        ? (Icons.arrow_upward, color, 'Favoured: recent parents sit ${v.toStringAsFixed(2)} sd above the population')
        : v < -_threshold
        ? (
            Icons.arrow_downward,
            color,
            'Selected against: recent parents sit ${(-v).toStringAsFixed(2)} sd below the population',
          )
        : (Icons.remove, Palette.faint, 'Neutral: recent parents look like the rest of the population');
    return Tooltip(
      message: tip,
      child: Icon(icon, size: 12, color: tone),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.items});

  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, color) in items) ...[
          Container(width: 10, height: 2, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Styles.label.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: Palette.faint),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );
  }
}

/// Details of the selected organism.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.frame,
      builder: (context, _, _) {
        final o = controller.selected;
        if (o == null) {
          return Section(
            title: 'Specimen',
            child: Text(
              'Tap a microbe to follow it: its species, its energy, its genome and its whole family. Tap empty '
              'water to pipette in some algae.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final world = controller.world;
        final config = world.config;
        final limits = config.limits;
        final threshold = world.reproductionThreshold(o.genome);
        final status = switch (o.deathCause) {
          null => 'Alive',
          DeathCause.starvation => 'Starved',
          DeathCause.oldAge => 'Died of old age',
          DeathCause.predation => 'Engulfed by a predator',
          DeathCause.disaster => 'Killed by UV',
        };
        final family = world.livingDescendants(o.id);
        final name = speciesName(o.family, o.genome);
        return Section(
          title: 'Specimen #${o.id}',
          trailing: InkWell(
            onTap: controller.clearSelection,
            child: Text('CLOSE', style: Styles.label.copyWith(color: Palette.faint)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: familyColor(o.family), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: explainName(name),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: Styles.display,
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$status · generation ${o.generation}${o.parentId == null ? ' (founder)' : ' · parent #${o.parentId}'}',
                style: TextStyle(fontSize: 13, color: o.alive ? Palette.cream : Palette.terracotta),
              ),
              const SizedBox(height: 12),
              _Meter(
                label: 'Energy',
                value: o.energy / threshold,
                detail: '${o.energy.round()} / ${threshold.round()} to divide',
                color: Palette.gold,
              ),
              _Meter(
                label: 'Age',
                value: o.age / (config.lifespan * config.ticksPerSecond),
                detail: '${formatClock(o.age / config.ticksPerSecond)} of ${formatClock(config.lifespan)}',
                color: Palette.muted,
              ),
              const SizedBox(height: 4),
              for (final trait in Trait.values)
                _Meter(
                  label: trait.label,
                  value: limits.of(trait).normalize(o.genome[trait]),
                  detail: o.genome[trait].toStringAsFixed(trait == Trait.sense ? 0 : 2),
                  color: Palette.trait(trait),
                ),
              const SizedBox(height: 6),
              Text(
                '${o.meals} algae eaten · ${o.offspring} divisions${config.predation ? ' · ${o.kills} engulfed' : ''}',
                style: Styles.readout.copyWith(fontSize: 12, color: Palette.muted),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                decoration: BoxDecoration(color: Palette.surface, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  family == 0
                      ? (o.alive
                            ? 'No living descendants yet. It needs ${threshold.round()} energy to divide.'
                            : 'This line has ended: none of its descendants are alive.')
                      : '$family living descendant${family == 1 ? '' : 's'}, circled in the drop. '
                            '${o.alive ? 'Its traits are spreading.' : 'Its line lives on after it.'}',
                  style: const TextStyle(fontSize: 12.5, height: 1.4, color: Palette.muted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.detail, required this.color});

  final String label;
  final double value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1).toDouble(),
                minHeight: 4,
                color: color,
                backgroundColor: Palette.raised,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(detail, textAlign: TextAlign.right, style: Styles.readout.copyWith(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
