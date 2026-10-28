import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../sim/world_config.dart';
import '../lab_controller.dart';
import '../microbes.dart';
import '../sprites.dart';
import '../theme.dart';
import 'field_view.dart';
import 'panels.dart';

/// Preparing a sample: choose a drop, tune its conditions, pick a seed.
class SetupPanel extends StatefulWidget {
  const SetupPanel({super.key, required this.controller});

  final LabController controller;

  @override
  State<SetupPanel> createState() => _SetupPanelState();
}

class _SetupPanelState extends State<SetupPanel> {
  late WorldConfig _draft = widget.controller.config;
  late final TextEditingController _seed = TextEditingController(text: '${widget.controller.config.seed}');

  WorldConfig get _live => widget.controller.config;

  int? get _draftSeed => int.tryParse(_seed.text.trim());

  /// Names of the conditions that differ from the running sample.
  List<String> get _changes => [
    if (_draft.foodPerSecond != _live.foodPerSecond) 'algae growth',
    if (_draft.foodEnergy != _live.foodEnergy) 'algae energy',
    if (_draft.seasonStrength != _live.seasonStrength) 'light cycle',
    if (_draft.initialPopulation != _live.initialPopulation) 'founders',
    if (_draft.mutationStrength != _live.mutationStrength) 'mutation',
    if (_draft.lifespan != _live.lifespan) 'lifespan',
    if (_draft.predation != _live.predation) 'predators',
    if (_draftSeed != null && _draftSeed != _live.seed) 'seed',
  ];

  @override
  void didUpdateWidget(SetupPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_changes.isEmpty || _draftSeed == null) {
      _draft = _live;
      if (_seed.text != '${_live.seed}') _seed.text = '${_live.seed}';
    }
  }

  void _choose(Preset preset) {
    widget.controller.restart(preset: preset);
    setState(() {
      _draft = widget.controller.config;
      _seed.text = '${_draft.seed}';
    });
  }

  void _apply() {
    widget.controller.restart(config: _draft, seed: _draftSeed ?? _live.seed);
    setState(() => _draft = widget.controller.config);
  }

  void _discard() => setState(() {
    _draft = _live;
    _seed.text = '${_live.seed}';
  });

  void _rollSeed() => setState(() => _seed.text = '${math.Random().nextInt(9000) + 1000}');

  Future<void> _copyCsv() async {
    await Clipboard.setData(ClipboardData(text: widget.controller.exportCsv()));
    if (!mounted) return;
    final rows = widget.controller.world.history.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $rows rows of data to the clipboard.')));
  }

  @override
  void dispose() {
    _seed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final active = controller.lesson == null ? controller.preset : null;
    final changes = _changes;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          title: 'Sample',
          trailing: Text(
            active == null ? 'custom' : 'running',
            style: Styles.label.copyWith(color: Palette.faint, fontWeight: FontWeight.w400),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 520 ? 4 : 2;
              const gap = 10.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final preset in Preset.values)
                    SizedBox(
                      width: width,
                      child: _SampleCard(preset: preset, active: preset == active, onTap: () => _choose(preset)),
                    ),
                ],
              );
            },
          ),
        ),
        Section(
          title: 'Conditions',
          trailing: Text(
            'apply to restart the sample',
            style: Styles.label.copyWith(color: Palette.faint, fontWeight: FontWeight.w400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GroupLabel(icon: Icons.water_drop_outlined, text: 'Water'),
              _Condition(
                label: 'Algae growth',
                hint: 'New algae cells per second. More food means bigger crowds and weaker selection.',
                value: _draft.foodPerSecond,
                min: 0,
                max: 25,
                divisions: 50,
                format: (v) => '${v.toStringAsFixed(1)} / s',
                changed: _draft.foodPerSecond != _live.foodPerSecond,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(foodPerSecond: v)),
              ),
              _Condition(
                label: 'Algae energy',
                hint: 'Energy in each alga. Richer algae let costly traits pay off.',
                value: _draft.foodEnergy,
                min: 15,
                max: 120,
                divisions: 21,
                format: (v) => '${v.round()}',
                changed: _draft.foodEnergy != _live.foodEnergy,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(foodEnergy: v)),
              ),
              _Condition(
                label: 'Light cycle',
                hint: 'How far the lamp swings between bright and dim. Strong cycles cause boom and bust.',
                value: _draft.seasonStrength,
                min: 0,
                max: 1,
                divisions: 20,
                format: (v) => v == 0 ? 'off' : '±${(v * 100).round()}%',
                changed: _draft.seasonStrength != _live.seasonStrength,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(seasonStrength: v)),
              ),
              const SizedBox(height: 6),
              const _GroupLabel(icon: Icons.bubble_chart_outlined, text: 'Microbes'),
              _Condition(
                label: 'Founders',
                hint: 'Microbes in the drop at the start. Each one starts its own family.',
                value: _draft.initialPopulation.toDouble(),
                min: 4,
                max: 120,
                divisions: 116,
                format: (v) => '${v.round()}',
                changed: _draft.initialPopulation != _live.initialPopulation,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(initialPopulation: v.round())),
              ),
              _Condition(
                label: 'Mutation',
                hint: 'How much a daughter can differ from its parent. Zero means perfect clones.',
                value: _draft.mutationStrength,
                min: 0,
                max: 0.3,
                divisions: 30,
                format: (v) => v == 0 ? 'none' : '${(v * 100).round()}%',
                changed: _draft.mutationStrength != _live.mutationStrength,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(mutationStrength: v)),
              ),
              _Condition(
                label: 'Lifespan',
                hint: 'Longest a microbe can live, in simulated seconds.',
                value: _draft.lifespan,
                min: 30,
                max: 300,
                divisions: 27,
                format: (v) => '${v.round()} s',
                changed: _draft.lifespan != _live.lifespan,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(lifespan: v)),
              ),
              _Toggle(
                label: 'Predators',
                hint: 'Microbes 1.3× larger can engulf smaller ones.',
                value: _draft.predation,
                changed: _draft.predation != _live.predation,
                onChanged: (v) => setState(() => _draft = _draft.copyWith(predation: v)),
              ),
              const SizedBox(height: 6),
              const _GroupLabel(icon: Icons.casino_outlined, text: 'Seed'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seed,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      style: Styles.readout,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Palette.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: _draftSeed != _live.seed ? Palette.gold : Palette.lineStrong),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Palette.gold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Pick a random seed',
                    child: IconButton.outlined(
                      onPressed: _rollSeed,
                      icon: const Icon(Icons.casino_outlined, size: 18),
                      color: Palette.cream,
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: Palette.lineStrong),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'The same seed and conditions always replay exactly the same run.',
                style: theme.bodySmall!.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 14),
              _ApplyBar(changes: changes, onApply: _apply, onDiscard: _discard),
            ],
          ),
        ),
        Section(
          title: 'Data',
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: Palette.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Palette.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_outlined, size: 20, color: Palette.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lab notebook', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${controller.world.history.length} readings: population, algae, deaths, families and traits.',
                        style: theme.bodySmall!.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _copyCsv,
                  icon: const Icon(Icons.copy, size: 15),
                  label: const Text('Copy CSV'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.cream,
                    side: const BorderSide(color: Palette.lineStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.preset, required this.active, required this.onTap});

  final Preset preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '${preset.label} sample. ${preset.summary}',
      child: Material(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? Palette.gold : Palette.line, width: active ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(painter: _SampleThumbPainter(preset)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(preset.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    if (active) const Icon(Icons.check_circle, size: 14, color: Palette.gold),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preset.sample.toLowerCase(),
                  style: Styles.label.copyWith(fontSize: 9.5, fontWeight: FontWeight.w400, color: Palette.faint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A still from each sample, drawn with the same figures as the live view.
class _SampleThumbPainter extends CustomPainter {
  _SampleThumbPainter(this.preset) : super(repaint: Sprites.current);

  final Preset preset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dim = preset == Preset.puddle;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: dim ? [Slide.dim, Slide.dimEdge] : [Slide.bright, Slide.brightEdge],
        ).createShader(rect),
    );

    final rng = math.Random(preset.index * 31 + 7);
    final algae = switch (preset) {
      Preset.bloom => 26,
      Preset.puddle => 3,
      _ => 9,
    };
    final sprites = Sprites.current.value;
    for (var i = 0; i < algae; i++) {
      final at = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      if (sprites != null) {
        final level = sprites.forAlgae(2.4);
        final r = 2.4 * (i % 4 == 0 ? 1.5 : 1);
        canvas.drawImageRect(
          level.algae,
          level.algaeFrame(i % 4 == 0 ? 1 : 0),
          Rect.fromCenter(center: at, width: r / Sprites.algaeRadius * 64, height: r / Sprites.algaeRadius * 64),
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        paintAlgae(canvas, at, 2.2);
      }
    }

    final cells = <MicrobeDraw>[];
    final count = preset == Preset.predators ? 5 : (preset == Preset.bloom ? 9 : 6);
    for (var i = 0; i < count; i++) {
      final big = preset == Preset.predators && i < 2;
      cells.add(
        MicrobeDraw(
          center: Offset(size.width * (0.12 + rng.nextDouble() * 0.76), size.height * (0.15 + rng.nextDouble() * 0.7)),
          radius: big ? 10 : 6,
          color: familyColor(big ? 5 : i % 4),
          heading: rng.nextDouble() * 2 * math.pi,
          speed: preset == Preset.bloom ? 2.2 : (preset == Preset.puddle ? 0.7 : 1.2),
          sense: big ? 120 : 40,
          energyShare: preset == Preset.puddle ? 0.2 : 0.6,
          seed: i,
        ),
      );
    }
    if (sprites != null) {
      paintMicrobeFigures(canvas, sprites, cells, 1.1);
    } else {
      for (final m in cells) {
        paintMicrobe(
          canvas,
          m.center,
          m.radius,
          color: m.color,
          heading: m.heading,
          speed: m.speed,
          sense: m.sense,
          energyShare: m.energyShare,
          phase: 1.1,
          seed: m.seed,
        );
      }
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SampleThumbPainter oldDelegate) => oldDelegate.preset != preset;
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Palette.muted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Palette.cream),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Palette.line, height: 1)),
        ],
      ),
    );
  }
}

class _Condition extends StatelessWidget {
  const _Condition({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.changed,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final bool changed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13, color: Palette.cream)),
              ),
              _ValueChip(text: format(value), changed: changed),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: format,
              onChanged: onChanged,
            ),
          ),
          Text(hint, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.hint,
    required this.value,
    required this.changed,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final bool changed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, color: Palette.cream)),
                    if (changed) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Palette.gold, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(hint, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.text, required this.changed});

  final String text;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: changed ? Palette.gold.withValues(alpha: 0.14) : Palette.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: changed ? Palette.gold : Palette.line),
      ),
      child: Text(text, style: Styles.readout.copyWith(fontSize: 11.5, color: changed ? Palette.gold : Palette.cream)),
    );
  }
}

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.changes, required this.onApply, required this.onDiscard});

  final List<String> changes;
  final VoidCallback onApply;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final dirty = changes.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: dirty ? Palette.gold.withValues(alpha: 0.08) : Palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dirty ? Palette.gold.withValues(alpha: 0.6) : Palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dirty ? 'Changed: ${changes.join(', ')}' : 'Conditions match the running sample.',
              style: TextStyle(fontSize: 12.5, color: dirty ? Palette.cream : Palette.faint),
            ),
          ),
          if (dirty) ...[
            TextButton(
              onPressed: onDiscard,
              style: TextButton.styleFrom(foregroundColor: Palette.muted),
              child: const Text('Discard'),
            ),
            const SizedBox(width: 4),
          ],
          FilledButton(
            onPressed: dirty ? onApply : null,
            style: FilledButton.styleFrom(
              backgroundColor: Palette.gold,
              foregroundColor: Palette.surface,
              disabledBackgroundColor: Palette.raised,
              disabledForegroundColor: Palette.faint,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Restart sample'),
          ),
        ],
      ),
    );
  }
}
