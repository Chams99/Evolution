import 'package:flutter/material.dart';

import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../microbes.dart';
import '../sprites.dart';
import '../theme.dart';
import 'field_view.dart';

/// What everything in the drop means, drawn with the same painters as the
/// live view, on a card the colour of the slide.
class FieldGuide extends StatelessWidget {
  const FieldGuide({super.key, required this.controller, this.overlay = true});

  final LabController controller;

  /// Floating card on the view (wide screens) or a plain block (phones).
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final predation = controller.config.predation;
    final rows = <(_Glyph, String)>[
      (_Glyph.cell, 'A microbe. It swells and fills with granules as it feeds.'),
      (_Glyph.dividing, 'Two nuclei: it is about to divide in two.'),
      (_Glyph.flagellum, 'Its tail (flagellum) shows speed. Longer, faster whipping means quicker.'),
      (_Glyph.eyespot, 'The red eyespot shows sense. Bigger spot, sees further.'),
      (_Glyph.families, 'Colour is family. Each founder has its own, passed on to every descendant.'),
      (_Glyph.algae, 'Algae: food. Grows faster when the lamp is bright.'),
      (_Glyph.starved, 'A grey, shrivelled ghost: it starved.'),
      if (predation) (_Glyph.eaten, 'A burst: eaten by a larger microbe.'),
    ];
    const text = Slide.ink;
    final open = controller.showGuide;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: overlay ? 276 : null,
      padding: EdgeInsets.fromLTRB(14, 10, 10, open ? 6 : 10),
      decoration: BoxDecoration(
        color: Slide.bright,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Slide.ink.withValues(alpha: 0.2)),
        boxShadow: overlay ? const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 4))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: open ? 'Collapse the field guide' : 'Show the field guide',
            child: InkWell(
              onTap: controller.toggleGuide,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  const Icon(Icons.biotech_outlined, size: 16, color: Slide.ink),
                  const SizedBox(width: 8),
                  Text("WHAT YOU'RE LOOKING AT", style: Styles.label.copyWith(color: Slide.ink)),
                  const Spacer(),
                  Icon(open ? Icons.expand_less : Icons.expand_more, size: 18, color: Slide.ghost),
                ],
              ),
            ),
          ),
          if (open) const SizedBox(height: 8),
          if (open)
            for (final (glyph, line) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 44, height: 28, child: CustomPaint(painter: _GlyphPainter(glyph))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line, style: const TextStyle(fontSize: 12, height: 1.3, color: text)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

enum _Glyph { cell, dividing, flagellum, eyespot, families, algae, starved, eaten }

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph) : super(repaint: Sprites.current);

  final _Glyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero) + const Offset(4, 0);
    final stain = familyColor(0);
    void cell(Offset at, double r, {Color? color, double speed = 1, double sense = 40, double energy = 0.5}) =>
        paintSpecimen(canvas, at, r, color: color ?? stain, speed: speed, sense: sense, energy: energy);
    void algae(Offset at, double r, int variant) => paintAlgaeSpecimen(canvas, at, r, variant);

    switch (glyph) {
      case _Glyph.cell:
        cell(c, 7, energy: 0.6);
      case _Glyph.dividing:
        cell(c, 8, energy: 1);
      case _Glyph.flagellum:
        cell(Offset(c.dx + 8, c.dy - 6), 3.6, speed: 0.4);
        cell(Offset(c.dx + 8, c.dy + 7), 3.6, speed: 3);
      case _Glyph.eyespot:
        cell(Offset(c.dx - 2, c.dy), 4.5, sense: 15);
        cell(Offset(c.dx + 14, c.dy), 4.5, sense: 170);
      case _Glyph.families:
        cell(Offset(c.dx - 12, c.dy - 5), 3.6, color: familyColor(1));
        cell(Offset(c.dx + 2, c.dy + 6), 3.6, color: familyColor(2));
        cell(Offset(c.dx + 14, c.dy - 4), 3.6, color: familyColor(5));
      case _Glyph.algae:
        algae(c + const Offset(-11, 3), 3.2, 0);
        algae(c + const Offset(2, -4), 4.6, 1);
        algae(c + const Offset(12, 5), 4.4, 2);
      case _Glyph.starved:
        paintGhost(canvas, c, 7, DeathCause.starvation, 0.2);
      case _Glyph.eaten:
        paintGhost(canvas, c, 5, DeathCause.predation, 0.25, color: familyColor(4));
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph;
}

/// One line under the view saying what is happening right now.
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
                // Fade only when the sentence changes; counts that tick at high speed update in place.
                key: ValueKey(controller.narration.replaceAll(RegExp(r'\d+'), '#')),
                style: const TextStyle(fontSize: 13.5, height: 1.45, color: Palette.cream),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
