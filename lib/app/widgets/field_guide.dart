import 'package:flutter/material.dart';

import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../microbes.dart';
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
    const text = Color(0xFF2A262C);
    return Container(
      width: overlay ? 276 : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xF2F4F3EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33000000)),
        boxShadow: overlay ? const [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4))] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('FIELD GUIDE', style: Styles.label.copyWith(color: const Color(0xFF8A5BB0))),
              const Spacer(),
              Semantics(
                button: true,
                label: 'Close the field guide',
                child: InkWell(
                  onTap: controller.toggleGuide,
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Color(0xFF6A6570)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
  const _GlyphPainter(this.glyph);

  final _Glyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero) + const Offset(4, 0);
    final violet = familyColor(0);
    void cell(Offset at, double r, {Color? color, double speed = 1, double sense = 40, double energy = 0.5}) =>
        paintMicrobe(
          canvas,
          at,
          r,
          color: color ?? violet,
          heading: 0,
          speed: speed,
          sense: sense,
          energyShare: energy,
          phase: 1.3,
          seed: 3,
        );
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
        paintAlgae(canvas, c + const Offset(-10, 3), 3);
        paintAlgae(canvas, c + const Offset(1, -5), 3.4);
        paintAlgae(canvas, c + const Offset(10, 5), 2.8);
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
