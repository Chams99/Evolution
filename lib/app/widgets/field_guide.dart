import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../theme.dart';
import 'field_view.dart';

/// What every shape and colour on the field means, drawn with the same
/// painters as the field itself.
class FieldGuide extends StatelessWidget {
  const FieldGuide({super.key, required this.controller, this.overlay = true});

  final LabController controller;

  /// Floating card on the field (wide screens) or a plain block (phones).
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final predation = controller.config.predation;
    final rows = <(_Glyph, String)>[
      (_Glyph.organism, 'An organism. The ring is its energy: when it closes, it splits in two.'),
      (_Glyph.speed, 'Colour and wake show speed: terracotta is slow, gold with a long wake is fast.'),
      (_Glyph.size, 'A bigger body means a larger size trait.'),
      (_Glyph.food, 'Food. Eating it fills the ring.'),
      (_Glyph.birth, 'A birth.'),
      (_Glyph.starved, 'Starved: ran out of energy.'),
      if (predation) (_Glyph.eaten, 'Eaten by a larger organism.'),
    ];
    return Container(
      width: overlay ? 262 : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
      decoration: BoxDecoration(
        color: overlay ? Palette.ink.withValues(alpha: 0.9) : Palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('FIELD GUIDE', style: Styles.label.copyWith(color: Palette.gold)),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Close the field guide',
                child: InkWell(
                  onTap: controller.toggleGuide,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Palette.faint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (glyph, text) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 40, height: 26, child: CustomPaint(painter: _GlyphPainter(glyph))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.3, color: Palette.cream)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _Glyph { organism, speed, size, food, birth, starved, eaten }

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph);

  final _Glyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    switch (glyph) {
      case _Glyph.organism:
        paintOrganism(
          canvas,
          c + const Offset(4, 0),
          6,
          color: Palette.terracotta,
          heading: 0,
          speed: 1,
          energyShare: 0.65,
        );
      case _Glyph.speed:
        paintOrganism(
          canvas,
          Offset(9, c.dy - 5),
          4,
          color: Palette.terracotta,
          heading: 0,
          speed: 0.4,
          energyShare: 0,
          showEnergy: false,
        );
        paintOrganism(
          canvas,
          Offset(size.width - 5, c.dy + 6),
          4,
          color: Palette.gold,
          heading: 0,
          speed: 3,
          energyShare: 0,
          showEnergy: false,
        );
      case _Glyph.size:
        paintOrganism(
          canvas,
          Offset(8, c.dy),
          3.5,
          color: Palette.terracotta,
          heading: -math.pi / 2,
          speed: 1,
          energyShare: 0,
          showEnergy: false,
        );
        paintOrganism(
          canvas,
          Offset(size.width - 12, c.dy),
          8,
          color: Palette.terracotta,
          heading: -math.pi / 2,
          speed: 1,
          energyShare: 0,
          showEnergy: false,
        );
      case _Glyph.food:
        paintFood(canvas, c + const Offset(-8, 2), 2.6);
        paintFood(canvas, c + const Offset(4, -5), 2.6);
        paintFood(canvas, c + const Offset(10, 6), 2.6);
      case _Glyph.birth:
        paintBirth(canvas, c, 5, 0.35);
      case _Glyph.starved:
        paintDeath(canvas, c, 5, DeathCause.starvation, 0.1);
      case _Glyph.eaten:
        paintDeath(canvas, c, 4, DeathCause.predation, 0.3);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph;
}

/// One line under the field saying what is happening right now.
class FieldCaption extends StatelessWidget {
  const FieldCaption({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller.samples,
      builder: (context, _, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.visibility_outlined, size: 15, color: Palette.gold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
              child: Text(
                controller.narration,
                key: ValueKey(controller.narration),
                style: const TextStyle(fontSize: 13.5, height: 1.45, color: Palette.cream),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
