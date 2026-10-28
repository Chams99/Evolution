import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../microbes.dart';
import '../theme.dart';

/// Radius of the UV pulse tool, in world units (micrometres).
const double meteorRadius = 70;

/// Microbes are drawn larger than their collision radius so their parts read.
const double bodyScale = 1.7;

/// Colours of the slide under the lamp.
abstract final class Slide {
  static const bright = Color(0xFFEEEFE2);
  static const brightEdge = Color(0xFFC4C8B2);
  static const dim = Color(0xFFC9CDC6);
  static const dimEdge = Color(0xFF8E948F);
  static const ink = Color(0xFF1E1B22);
  static const eyespot = Color(0xFFC8372B);
  static const algae = Color(0xFF5D9A47);
  static const algaeRim = Color(0xFF3B6A2E);
  static const ghost = Color(0xFF8B8A86);
}

/// The live view of the drop, scaled to fit while keeping its aspect ratio.
class FieldView extends StatefulWidget {
  const FieldView({super.key, required this.controller});

  final LabController controller;

  @override
  State<FieldView> createState() => _FieldViewState();
}

class _FieldViewState extends State<FieldView> {
  final ValueNotifier<Offset?> _hover = ValueNotifier(null);

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final config = controller.config;
    final uv = controller.tool == Tool.meteor;
    return AspectRatio(
      aspectRatio: config.width / config.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / config.width;
          return MouseRegion(
            cursor: uv ? SystemMouseCursors.precise : SystemMouseCursors.click,
            onHover: (event) => _hover.value = event.localPosition / scale,
            onExit: (_) => _hover.value = null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  controller.tapField(details.localPosition.dx / scale, details.localPosition.dy / scale),
              child: Semantics(
                label: uv
                    ? 'Microscope view. Tap to fire a UV pulse.'
                    : 'Microscope view. Tap a microbe to follow it, or empty water to pipette algae.',
                child: RepaintBoundary(
                  child: CustomPaint(painter: _FieldPainter(controller, _hover), size: Size.infinite),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A microbe: translucent cell with a wobbling membrane, cytoplasm granules
/// that show stored energy, a nucleus (two when it is about to divide), a red
/// eyespot sized by its sense, and a whipping flagellum sized by its speed.
void paintMicrobe(
  Canvas canvas,
  Offset c,
  double r, {
  required Color color,
  required double heading,
  required double speed,
  required double sense,
  required double energyShare,
  required double phase,
  int seed = 0,
}) {
  final share = energyShare.clamp(0.0, 1.0);
  final rv = r * (0.86 + 0.28 * share);
  final stretch = 1 + 0.1 * speed.clamp(0, 3.5);
  final dark = Color.lerp(color, Slide.ink, 0.45)!;

  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(heading);

  // Flagellum: a travelling wave behind the cell, longer and faster for quick swimmers.
  final flagellumLength = rv * (0.9 + speed * 1.3);
  final flagellum = Path()..moveTo(-rv * stretch * 0.92, 0);
  const segments = 14;
  for (var i = 1; i <= segments; i++) {
    final t = i / segments;
    final x = -rv * stretch * 0.92 - flagellumLength * t;
    final y = math.sin(t * 2.6 * math.pi - phase * (2 + speed)) * rv * 0.32 * t;
    flagellum.lineTo(x, y);
  }
  canvas.drawPath(
    flagellum,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, rv * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = dark.withValues(alpha: 0.75),
  );

  // Membrane, gently wobbling.
  final body = Path();
  const points = 22;
  for (var i = 0; i <= points; i++) {
    final a = i / points * 2 * math.pi;
    final wobble = 1 + 0.045 * math.sin(a * 3 + phase * 1.7 + seed) + 0.03 * math.sin(a * 5 - phase * 1.1);
    final p = Offset(math.cos(a) * rv * stretch * wobble, math.sin(a) * rv * wobble);
    i == 0 ? body.moveTo(p.dx, p.dy) : body.lineTo(p.dx, p.dy);
  }
  body.close();
  canvas.drawPath(
    body,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.25, -0.3),
        colors: [Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.55), color.withValues(alpha: 0.62)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rv * stretch)),
  );
  canvas.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, rv * 0.11)
      ..color = dark.withValues(alpha: 0.85),
  );

  // Granules: more stored energy, more of them.
  final granules = (share * 7).round();
  final granulePaint = Paint()..color = dark.withValues(alpha: 0.35);
  for (var i = 0; i < granules; i++) {
    final a = (seed * 37 + i * 83) % 360 * math.pi / 180;
    final d = rv * (0.3 + ((seed + i * 13) % 5) / 10);
    canvas.drawCircle(
      Offset(math.cos(a) * d * stretch * 0.8, math.sin(a) * d * 0.8),
      math.max(0.6, rv * 0.08),
      granulePaint,
    );
  }

  // Nucleus, splitting in two when the cell is about to divide.
  final nucleus = Paint()..color = dark.withValues(alpha: 0.6);
  final nr = math.max(1.0, rv * 0.3);
  if (share > 0.85) {
    canvas.drawCircle(Offset(-rv * 0.32, -rv * 0.12), nr * 0.85, nucleus);
    canvas.drawCircle(Offset(-rv * 0.32, rv * 0.32), nr * 0.85, nucleus);
  } else {
    canvas.drawCircle(Offset(-rv * 0.18, 0), nr, nucleus);
  }

  // Eyespot at the front: bigger for organisms that sense further.
  final eye = math.max(0.8, rv * (0.12 + sense / 180 * 0.3));
  canvas.drawCircle(
    Offset(rv * stretch * 0.62, -rv * 0.12),
    eye,
    Paint()..color = Slide.eyespot.withValues(alpha: 0.9),
  );

  canvas.restore();
}

/// An alga: a small green cell with a darker rim.
void paintAlgae(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r, Paint()..color = Slide.algae.withValues(alpha: 0.85));
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.25)
      ..color = Slide.algaeRim.withValues(alpha: 0.9),
  );
  canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.3), r * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.35));
}

/// Cell division: a pinching bridge between parent and child. [t] runs 0 to 1.
void paintDivision(Canvas canvas, Offset from, Offset to, double r, Color color, double t) {
  final fade = 1 - t;
  final mid = Offset.lerp(from, to, 0.5)!;
  canvas.drawLine(
    from,
    to,
    Paint()
      ..strokeWidth = r * 1.4 * (1 - 0.8 * t)
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.35 * fade),
  );
  canvas.drawCircle(
    mid,
    r * 0.5 * fade + 1,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Slide.ink.withValues(alpha: 0.45 * fade),
  );
}

/// A dead cell, fading. Starved cells shrivel to grey; eaten cells burst.
void paintGhost(Canvas canvas, Offset c, double r, DeathCause? cause, double t, {Color? color}) {
  final fade = 1 - t;
  switch (cause) {
    case DeathCause.predation:
      final burst = Paint()
        ..color = (color ?? Slide.eyespot).withValues(alpha: 0.7 * fade)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 9; i++) {
        final a = i * 2 * math.pi / 9 + 0.3;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * r * (0.6 + t), c + d * r * (1.1 + 1.4 * t), burst);
      }
    case DeathCause.starvation:
    case DeathCause.oldAge:
    case DeathCause.disaster:
    case null:
      final shrink = cause == DeathCause.starvation ? (1 - 0.35 * t) : 1.0;
      final ghost = Path();
      const points = 16;
      for (var i = 0; i <= points; i++) {
        final a = i / points * 2 * math.pi;
        final crumple = 1 + (cause == DeathCause.starvation ? 0.16 : 0.06) * math.sin(a * 6 + r);
        final p = c + Offset(math.cos(a), math.sin(a)) * r * shrink * crumple;
        i == 0 ? ghost.moveTo(p.dx, p.dy) : ghost.lineTo(p.dx, p.dy);
      }
      ghost.close();
      canvas.drawPath(ghost, Paint()..color = Slide.ghost.withValues(alpha: 0.28 * fade));
      canvas.drawPath(
        ghost,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Slide.ghost.withValues(alpha: 0.7 * fade),
      );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.controller, this.hover) : super(repaint: Listenable.merge([controller.frame, hover]));

  final LabController controller;
  final ValueNotifier<Offset?> hover;

  static const _divisionTicks = 30;
  static const _ghostTicks = 75;
  static const _debris = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final world = controller.world;
    final config = world.config;
    final scale = size.width / config.width;
    final now = world.tick;
    final phase = now / config.ticksPerSecond * 2 * math.pi;

    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.save();
    canvas.clipRRect(frame);

    // The slide, brighter when the lamp is up (more light, more algae).
    final swing = config.seasonStrength;
    final light = swing <= 0 ? 0.75 : ((world.foodSupply - (1 - swing)) / (2 * swing)).clamp(0.0, 1.0);
    final centre = Color.lerp(Slide.dim, Slide.bright, light)!;
    final edge = Color.lerp(Slide.dimEdge, Slide.brightEdge, light)!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = RadialGradient(radius: 0.85, colors: [centre, edge]).createShader(Offset.zero & size),
    );

    _paintDebris(canvas, size, now);
    _paintUvMarks(canvas, scale, now);

    for (final item in world.food) {
      final jitter = ((item.x * 13 + item.y * 7).floor() % 5) / 10;
      paintAlgae(canvas, Offset(item.x * scale, item.y * scale), math.max(1.8, (2.4 + jitter) * scale));
    }

    _paintEvents(canvas, scale, now, beneath: true);

    if (controller.showSense) {
      final senseFill = Paint()..color = Slide.ink.withValues(alpha: 0.05);
      for (final o in world.organisms) {
        canvas.drawCircle(Offset(o.x * scale, o.y * scale), o.genome.sense * scale, senseFill);
      }
    }

    final selected = controller.selected;
    final family = selected == null
        ? const <Organism>{}
        : {
            for (final o in world.organisms)
              if (world.descendsFrom(o, selected.id)) o,
          };
    final familyRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Slide.ink.withValues(alpha: 0.6);

    for (final o in world.organisms) {
      final c = Offset(o.x * scale, o.y * scale);
      final r = math.max(3.2, o.radius * scale * bodyScale);
      paintMicrobe(
        canvas,
        c,
        r,
        color: familyColor(o.family),
        heading: o.heading,
        speed: o.genome.speed,
        sense: o.genome.sense,
        energyShare: o.energy / world.reproductionThreshold(o.genome),
        phase: phase + o.id * 0.7,
        seed: o.id,
      );
      if (family.contains(o)) _dashedCircle(canvas, c, r * 1.5 + 4, familyRing);
    }

    _paintEvents(canvas, scale, now, beneath: false);

    if (selected != null && selected.alive) {
      final c = Offset(selected.x * scale, selected.y * scale);
      final r = math.max(3.2, selected.radius * scale * bodyScale);
      canvas.drawCircle(c, selected.genome.sense * scale, Paint()..color = Slide.ink.withValues(alpha: 0.05));
      _dashedCircle(
        canvas,
        c,
        selected.genome.sense * scale,
        Paint()
          ..color = Slide.ink.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        c,
        r * 1.5 + 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Slide.ink.withValues(alpha: 0.85),
      );
    }

    final aim = hover.value;
    if (controller.tool == Tool.meteor && aim != null) {
      final c = aim * scale;
      canvas.drawCircle(c, meteorRadius * scale, Paint()..color = const Color(0xFF7B5CFF).withValues(alpha: 0.08));
      _dashedCircle(
        canvas,
        c,
        meteorRadius * scale,
        Paint()
          ..color = const Color(0xFF5B3FD9).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Lens vignette.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.32)],
          stops: const [0, 0.62, 1],
        ).createShader(Offset.zero & size),
    );

    canvas.restore();
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Palette.lineStrong,
    );
  }

  /// Out-of-focus specks and fibres drifting in the water, for depth.
  void _paintDebris(Canvas canvas, Size size, int now) {
    final speck = Paint();
    for (var i = 0; i < _debris; i++) {
      final h = (i * 2654435761) & 0xFFFFFF;
      final baseX = (h % 1000) / 1000 * size.width;
      final baseY = ((h >> 10) % 1000) / 1000 * size.height;
      final driftX = math.sin(now / 900 + i) * 14;
      final driftY = (now * (0.02 + (i % 7) * 0.006)) % size.height;
      final p = Offset((baseX + driftX) % size.width, (baseY + driftY) % size.height);
      final r = 1.0 + (h % 9) * 0.7;
      speck.color = const Color(0xFF6E6B5E).withValues(alpha: 0.05 + (h % 5) * 0.025);
      if (i % 9 == 0) {
        final a = (h % 628) / 100;
        canvas.drawLine(
          p,
          p + Offset(math.cos(a), math.sin(a)) * (12 + r * 4),
          Paint()
            ..color = speck.color
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(p, r, speck);
      }
    }
  }

  /// Faint violet patches where UV pulses landed.
  void _paintUvMarks(Canvas canvas, double scale, int now) {
    for (final e in controller.world.events) {
      if (e.kind != EventKind.strike) continue;
      final age = (now - e.tick) / 240;
      if (age > 1) continue;
      canvas.drawCircle(
        Offset(e.x * scale, e.y * scale),
        e.size * scale,
        Paint()..color = const Color(0xFF7B5CFF).withValues(alpha: 0.12 * (1 - age)),
      );
    }
  }

  void _paintEvents(Canvas canvas, double scale, int now, {required bool beneath}) {
    for (final e in controller.world.events) {
      final c = Offset(e.x * scale, e.y * scale);
      final r = math.max(3.2, e.size * scale * bodyScale);
      switch (e.kind) {
        case EventKind.birth when beneath:
          final t = (now - e.tick) / _divisionTicks;
          if (t < 0 || t > 1 || e.fromX == null) continue;
          paintDivision(canvas, Offset(e.fromX! * scale, e.fromY! * scale), c, r, familyColor(e.family ?? 0), t);
        case EventKind.death when beneath:
          final t = (now - e.tick) / _ghostTicks;
          if (t < 0 || t > 1) continue;
          paintGhost(canvas, c, r, e.cause, t, color: familyColor(e.family ?? 0));
        case EventKind.strike when !beneath:
          final t = (now - e.tick) / 30;
          if (t < 0 || t > 1) continue;
          canvas.drawCircle(
            c,
            e.size * scale,
            Paint()..color = const Color(0xFFF1EDFF).withValues(alpha: 0.75 * (1 - t)),
          );
          canvas.drawCircle(
            c,
            e.size * scale * (0.6 + 0.5 * Curves.easeOut.transform(t)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * (1 - t) + 1
              ..color = const Color(0xFF5B3FD9).withValues(alpha: 0.8 * (1 - t)),
          );
        default:
          break;
      }
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    if (radius <= 0) return;
    final dashes = (radius * 2 * math.pi / 7).clamp(10, 160).round();
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => oldDelegate.controller != controller;
}
