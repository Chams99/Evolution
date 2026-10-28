import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../sim/genome.dart';
import 'experiment.dart';
import 'lab_controller.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/field_view.dart';

/// Opens the experiment screen, pausing the lab's own drop while it is open.
Future<void> openExperiment(BuildContext context, LabController lab) async {
  final wasPlaying = lab.playing;
  lab.pause();
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ExperimentScreen()));
  if (wasPlaying && !lab.playing) lab.togglePlaying();
}

/// Change one thing, predict what evolves, and compare against a control drop.
class ExperimentScreen extends StatefulWidget {
  const ExperimentScreen({super.key, this.experiment});

  final Experiment? experiment;

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen> with SingleTickerProviderStateMixin {
  late final Experiment _x = widget.experiment ?? Experiment();
  late final Ticker _ticker;
  final _scroll = ScrollController();
  Duration _last = Duration.zero;
  bool _wasRunning = false;

  @override
  void initState() {
    super.initState();
    _x.addListener(_rebuild);
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _last;
      _last = elapsed;
      _x.advance(delta > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : delta);
    })..start();
  }

  void _rebuild() {
    // Switching between setting up and running starts the page from the top.
    final running = _x.control != null;
    if (running != _wasRunning && _scroll.hasClients) _scroll.jumpTo(0);
    _wasRunning = running;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    _x.removeListener(_rebuild);
    if (widget.experiment == null) _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final control = _x.control, treated = _x.treated;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = constraints.maxWidth < 600 ? 16.0 : 28.0;
            return ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
              children: [
                _Header(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 18),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: control == null ? 760 : 1200),
                    child: control == null || treated == null
                        ? _Setup(experiment: _x)
                        : _Run(experiment: _x, control: control, treated: treated, wide: constraints.maxWidth >= 860),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Back to the lab',
          icon: const Icon(Icons.arrow_back, color: Palette.cream),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TEST AN IDEA', style: Styles.label.copyWith(color: Palette.terracotta)),
            const SizedBox(height: 2),
            Text('Your experiment', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ],
    );
  }
}

String _prediction(Experiment x) =>
    'Average ${x.trait.label.toLowerCase()} will end up ${x.direction.label} ${x.treatment.phrase} '
    'than in the control.';

class _Setup extends StatelessWidget {
  const _Setup({required this.experiment});

  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final x = experiment;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Change one thing. Predict. Compare.', style: theme.titleLarge?.copyWith(fontSize: 26)),
        const SizedBox(height: 8),
        Text(
          'Two drops start from the same seed: the same founders in the same places. One is left alone as the '
          'control, the other gets your change. If your prediction holds in drop after drop, the change is the '
          'cause.',
          style: theme.bodyMedium?.copyWith(color: Palette.muted),
        ),
        const SizedBox(height: 26),
        const _Step(number: 1, title: 'Change one thing'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final t in Treatment.values)
                  SizedBox(
                    width: width,
                    child: _Option(
                      minHeight: columns == 2 ? 92 : 0,
                      title: t.title,
                      detail: t.detail,
                      selected: x.treatment == t,
                      onTap: () => x.choose(treatment: t),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        const _Step(number: 2, title: 'Predict'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Average', style: TextStyle(fontSize: 15)),
            for (final t in Trait.values)
              _Chip(
                label: t.label,
                selected: x.trait == t,
                onTap: () => x.choose(trait: t),
              ),
            const Text('will end up', style: TextStyle(fontSize: 15)),
            for (final d in Direction.values)
              _Chip(
                label: d.label,
                selected: x.direction == d,
                onTap: () => x.choose(direction: d),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: const Border(left: BorderSide(color: Palette.gold, width: 3)),
          ),
          child: Text('Prediction: ${_prediction(x)}', style: const TextStyle(fontSize: 14, height: 1.45)),
        ),
        const SizedBox(height: 26),
        const _Step(number: 3, title: 'Run both drops'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: x.start,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Run the experiment'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.gold,
                foregroundColor: Palette.surface,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            Text(
              '${(Experiment.duration / 60).round()} simulated minutes at ${Experiment.speed}×, about a minute. '
              'You can finish early.',
              style: theme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text('$number · ${title.toUpperCase()}', style: Styles.label);
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.minHeight = 0,
  });

  final double minHeight;
  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected ? Palette.raised : Palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Palette.gold : Palette.line, width: selected ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? Palette.gold : Palette.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Palette.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? Palette.gold : Palette.lineStrong),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Palette.surface : Palette.cream,
            ),
          ),
        ),
      ),
    );
  }
}

class _Run extends StatelessWidget {
  const _Run({required this.experiment, required this.control, required this.treated, required this.wide});

  final Experiment experiment;
  final LabController control;
  final LabController treated;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final x = experiment;
    final theme = Theme.of(context).textTheme;
    final drops = [
      _Drop(controller: control, title: 'CONTROL', color: Palette.cream, trait: x.trait),
      _Drop(controller: treated, title: x.treatment.phrase.toUpperCase(), color: Palette.gold, trait: x.trait),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Prediction: ${_prediction(x)}', style: theme.bodyMedium),
        const SizedBox(height: 12),
        ValueListenableBuilder(
          valueListenable: control.samples,
          builder: (context, _, _) => Row(
            children: [
              Text(
                '${formatClock(x.elapsed.clamp(0, Experiment.duration).toDouble())} / ${formatClock(Experiment.duration)}',
                style: Styles.readout,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (x.elapsed / Experiment.duration).clamp(0, 1).toDouble(),
                    minHeight: 4,
                    color: Palette.gold,
                    backgroundColor: Palette.raised,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (x.running)
                TextButton(
                  onPressed: x.finishNow,
                  style: TextButton.styleFrom(foregroundColor: Palette.cream),
                  child: const Text('Finish now'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: drops[0]),
              const SizedBox(width: 14),
              Expanded(child: drops[1]),
            ],
          )
        else ...[
          drops[0],
          const SizedBox(height: 14),
          drops[1],
        ],
        const SizedBox(height: 18),
        Text('AVERAGE ${x.trait.label.toUpperCase()} IN BOTH DROPS', style: Styles.label),
        const SizedBox(height: 10),
        ValueListenableBuilder(
          valueListenable: treated.samples,
          builder: (context, _, _) => CompareChart(
            control: control.world.history,
            treated: treated.world.history,
            trait: x.trait,
            duration: Experiment.duration,
          ),
        ),
        if (x.done) ...[const SizedBox(height: 20), _Verdict(experiment: x)],
      ],
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({required this.controller, required this.title, required this.color, required this.trait});

  final LabController controller;
  final String title;
  final Color color;
  final Trait trait;

  @override
  Widget build(BuildContext context) {
    final digits = trait == Trait.sense ? 0 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder(
          valueListenable: controller.samples,
          builder: (context, _, _) {
            final world = controller.world;
            final mean = world.extinct ? null : world.history.last.traits[trait]!.mean;
            return Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: Styles.label.copyWith(color: color),
                  ),
                ),
                Text(
                  '${world.organisms.length} microbes · ${trait.label.toLowerCase()} '
                  '${mean == null ? '—' : mean.toStringAsFixed(digits)}',
                  style: Styles.readout.copyWith(fontSize: 12, color: Palette.muted),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        FieldView(controller: controller, interactive: false),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.experiment});

  final Experiment experiment;

  @override
  Widget build(BuildContext context) {
    final x = experiment;
    final r = x.results.last;
    final theme = Theme.of(context).textTheme;
    final trait = x.trait.label.toLowerCase();
    final digits = x.trait == Trait.sense ? 0 : 2;
    final confirmedCount = x.results.where((e) => e.confirmed).length;
    final (headline, color) = r.observed == null
        ? ('A drop died out', Palette.terracotta)
        : r.confirmed
        ? ('Prediction confirmed', Palette.gold)
        : ('Prediction not confirmed', Palette.terracotta);
    final change = (r.change * 100).round();
    final detail = r.observed == null
        ? 'One of the drops went sterile, so there is nothing to compare. Try another seed.'
        : 'Average $trait was ${r.treated!.toStringAsFixed(digits)} ${x.treatment.phrase} and '
              '${r.control!.toStringAsFixed(digits)} in the control (${change >= 0 ? '+' : ''}$change%). '
              '${r.observed == Direction.same ? 'That is within 5%, so about the same.' : 'It ended up ${r.observed!.label}.'}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RESULT · SEED ${r.seed}', style: Styles.label.copyWith(color: color)),
          const SizedBox(height: 6),
          Text(headline, style: theme.titleLarge),
          const SizedBox(height: 8),
          Text(detail, style: theme.bodyMedium),
          const SizedBox(height: 10),
          Text('The usual explanation: ${x.treatment.why}', style: theme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final e in x.results)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Seed ${e.seed}: ${e.confirmed ? 'confirmed' : 'not confirmed'}',
                    child: Icon(
                      e.confirmed ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: e.confirmed ? Palette.gold : Palette.terracotta,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Confirmed in $confirmedCount of ${x.results.length} drop${x.results.length == 1 ? '' : 's'}. '
                  '${x.results.length < 3 ? 'One drop can be luck: repeat it to see whether the result holds.' : 'The more drops agree, the stronger the case.'}',
                  style: theme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => x.start(nextSeed: true),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Repeat with a new seed'),
                style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.surface),
              ),
              OutlinedButton(
                onPressed: x.reset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.cream,
                  side: const BorderSide(color: Palette.lineStrong),
                ),
                child: const Text('Change the experiment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
