import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../../sim/organism.dart';
import '../lab_controller.dart';
import '../theme.dart';

/// Blast radius of the meteor tool, in world units.
const double meteorRadius = 70;

/// The world, scaled to fit while keeping its aspect ratio.
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
    final meteor = controller.tool == Tool.meteor;
    return AspectRatio(
      aspectRatio: config.width / config.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / config.width;
          return MouseRegion(
            cursor: meteor ? SystemMouseCursors.precise : SystemMouseCursors.click,
            onHover: (event) => _hover.value = event.localPosition / scale,
            onExit: (_) => _hover.value = null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  controller.tapField(details.localPosition.dx / scale, details.localPosition.dy / scale),
              child: Semantics(
                label: meteor
                    ? 'Simulation field. Tap to strike with a meteor.'
                    : 'Simulation field. Tap an organism to follow it, or empty ground to drop food.',
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

/// How much larger bodies are drawn than their collision radius, so they read at a glance.
const double bodyScale = 1.6;

/// One organism: soft glow, a wake whose length shows speed, the body, a
/// nucleus facing forward, and a ring showing how close it is to splitting.
void paintOrganism(
  Canvas canvas,
  Offset c,
  double r, {
  required Color color,
  required double heading,
  required double speed,
  required double energyShare,
  bool showEnergy = true,
}) {
  final direction = Offset(math.cos(heading), math.sin(heading));
  final side = Offset(-direction.dy, direction.dx);

  canvas.drawCircle(
    c,
    r * 2.6,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.6)),
  );

  final length = r * (0.6 + speed * 0.9);
  final tip = c - direction * (r + length);
  final back = c - direction * (r + length * 0.45);
  final wake = Path()
    ..moveTo(c.dx + side.dx * r, c.dy + side.dy * r)
    ..cubicTo(
      c.dx - direction.dx * r * 0.6 + side.dx * r,
      c.dy - direction.dy * r * 0.6 + side.dy * r,
      back.dx + side.dx * r * 0.35,
      back.dy + side.dy * r * 0.35,
      tip.dx,
      tip.dy,
    )
    ..cubicTo(
      back.dx - side.dx * r * 0.35,
      back.dy - side.dy * r * 0.35,
      c.dx - direction.dx * r * 0.6 - side.dx * r,
      c.dy - direction.dy * r * 0.6 - side.dy * r,
      c.dx - side.dx * r,
      c.dy - side.dy * r,
    )
    ..close();
  canvas.drawPath(
    wake,
    Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.75), color.withValues(alpha: 0)],
      ).createShader(Rect.fromPoints(c, tip)),
  );

  canvas.drawCircle(c, r, Paint()..color = color);
  canvas.drawCircle(
    c + direction * (r * 0.35),
    math.max(1.0, r * 0.3),
    Paint()..color = Palette.cream.withValues(alpha: 0.65),
  );

  if (showEnergy) {
    final ring = Rect.fromCircle(center: c, radius: r + math.max(1.6, r * 0.32));
    final width = math.max(1.2, r * 0.22);
    canvas.drawArc(
      ring,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = Palette.cream.withValues(alpha: 0.12),
    );
    final share = energyShare.clamp(0.0, 1.0);
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * share,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(Palette.cream.withValues(alpha: 0.55), Palette.cream, share)!,
    );
  }
}

/// A food item: a small bright speck with a halo.
void paintFood(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(c, r * 2.6, Paint()..color = Palette.food.withValues(alpha: 0.16));
  canvas.drawCircle(c, r, Paint()..color = Palette.food);
}

/// A birth: a bright ring expanding from the newborn. [t] runs from 0 to 1.
void paintBirth(Canvas canvas, Offset c, double r, double t) {
  canvas.drawCircle(c, r * (1 + 0.6 * (1 - t)), Paint()..color = Palette.cream.withValues(alpha: 0.35 * (1 - t)));
  canvas.drawCircle(
    c,
    r + 4 + 18 * Curves.easeOut.transform(t),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Palette.cream.withValues(alpha: 0.85 * (1 - t)),
  );
}

/// A death, marked by cause: a cross for starvation, a burst for predation,
/// a fading ring for old age. [t] runs from 0 to 1.
void paintDeath(Canvas canvas, Offset c, double r, DeathCause? cause, double t) {
  final fade = 1 - t;
  switch (cause) {
    case DeathCause.predation:
      final paint = Paint()
        ..color = Palette.rust.withValues(alpha: 0.9 * fade)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, r * 0.9, Paint()..color = Palette.rust.withValues(alpha: 0.55 * fade));
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * (r + 2), c + d * (r + 4 + 10 * t), paint);
      }
    case DeathCause.starvation:
      final paint = Paint()
        ..color = Palette.muted.withValues(alpha: 0.85 * fade)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final s = r * 0.75 + 2;
      canvas.drawLine(c + Offset(-s, -s), c + Offset(s, s), paint);
      canvas.drawLine(c + Offset(-s, s), c + Offset(s, -s), paint);
    case DeathCause.oldAge:
      canvas.drawCircle(
        c,
        r + 6 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Palette.muted.withValues(alpha: 0.6 * fade),
      );
    case DeathCause.disaster:
    case null:
      canvas.drawCircle(c, r * fade, Paint()..color = Palette.terracotta.withValues(alpha: 0.5 * fade));
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.controller, this.hover) : super(repaint: Listenable.merge([controller.frame, hover]));

  final LabController controller;
  final ValueNotifier<Offset?> hover;

  static const _gridStep = 60.0;
  static const _dry = Color(0xFF1C1411);
  static const _lush = Color(0xFF101A14);

  /// How long effects stay on screen, in ticks.
  static const _birthTicks = 24;
  static const _deathTicks = 45;

  @override
  void paint(Canvas canvas, Size size) {
    final world = controller.world;
    final config = world.config;
    final scale = size.width / config.width;
    final limits = config.limits;
    final now = world.tick;

    // Ground: drier and warmer when food is short, greener when it is plentiful.
    final swing = config.seasonStrength;
    final wetness = swing <= 0 ? 0.5 : ((world.foodSupply - (1 - swing)) / (2 * swing)).clamp(0.0, 1.0);
    final ground = Color.lerp(_dry, _lush, wetness)!;
    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(frame, Paint()..color = ground);
    canvas.save();
    canvas.clipRRect(frame);

    final grid = Paint()
      ..color = Palette.cream.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (var x = _gridStep; x < config.width; x += _gridStep) {
      canvas.drawLine(Offset(x * scale, 0), Offset(x * scale, size.height), grid);
    }
    for (var y = _gridStep; y < config.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y * scale), Offset(size.width, y * scale), grid);
    }

    _paintScorch(canvas, scale, now);

    final foodRadius = math.max(2.0, 2.8 * scale);
    for (final item in world.food) {
      paintFood(canvas, Offset(item.x * scale, item.y * scale), foodRadius);
    }

    if (controller.showSense) {
      final senseFill = Paint()..color = Palette.steel.withValues(alpha: 0.05);
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
      ..strokeWidth = 1.5
      ..color = Palette.cream.withValues(alpha: 0.8);

    for (final o in world.organisms) {
      final c = Offset(o.x * scale, o.y * scale);
      final r = math.max(3.0, o.radius * scale * bodyScale);
      paintOrganism(
        canvas,
        c,
        r,
        color: organismColor(o.genome, limits),
        heading: o.heading,
        speed: o.genome.speed,
        energyShare: o.energy / world.reproductionThreshold(o.genome),
      );
      if (family.contains(o)) canvas.drawCircle(c, r + 7, familyRing);
    }

    _paintEvents(canvas, scale, now);

    if (selected != null && selected.alive) {
      final c = Offset(selected.x * scale, selected.y * scale);
      final r = math.max(3.0, selected.radius * scale * bodyScale);
      canvas.drawCircle(c, selected.genome.sense * scale, Paint()..color = Palette.steel.withValues(alpha: 0.07));
      _dashedCircle(
        canvas,
        c,
        selected.genome.sense * scale,
        Paint()
          ..color = Palette.steel.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        c,
        r + 8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Palette.cream,
      );
    }

    final aim = hover.value;
    if (controller.tool == Tool.meteor && aim != null) {
      final c = aim * scale;
      canvas.drawCircle(c, meteorRadius * scale, Paint()..color = Palette.terracotta.withValues(alpha: 0.08));
      _dashedCircle(
        canvas,
        c,
        meteorRadius * scale,
        Paint()
          ..color = Palette.terracotta.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    canvas.restore();
    canvas.drawRRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Palette.line,
    );
  }

  /// Fading burn marks where meteors landed.
  void _paintScorch(Canvas canvas, double scale, int now) {
    for (final e in controller.world.events) {
      if (e.kind != EventKind.strike) continue;
      final age = (now - e.tick) / 240;
      if (age > 1) continue;
      canvas.drawCircle(
        Offset(e.x * scale, e.y * scale),
        e.size * scale,
        Paint()..color = const Color(0xFF2A1712).withValues(alpha: 0.7 * (1 - age)),
      );
    }
  }

  void _paintEvents(Canvas canvas, double scale, int now) {
    for (final e in controller.world.events) {
      final c = Offset(e.x * scale, e.y * scale);
      final r = math.max(3.0, e.size * scale * bodyScale);
      switch (e.kind) {
        case EventKind.birth:
          final t = (now - e.tick) / _birthTicks;
          if (t >= 0 && t <= 1) paintBirth(canvas, c, r, t);
        case EventKind.death:
          final t = (now - e.tick) / _deathTicks;
          if (t >= 0 && t <= 1 && e.cause != DeathCause.disaster) paintDeath(canvas, c, r, e.cause, t);
        case EventKind.strike:
          final t = (now - e.tick) / 36;
          if (t < 0 || t > 1) continue;
          canvas.drawCircle(
            c,
            e.size * scale * (0.3 + 0.9 * Curves.easeOut.transform(t)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * (1 - t) + 1
              ..color = Palette.terracotta.withValues(alpha: 0.9 * (1 - t)),
          );
          canvas.drawCircle(c, e.size * scale * 0.5, Paint()..color = Palette.gold.withValues(alpha: 0.35 * (1 - t)));
        case EventKind.famine:
        case EventKind.rain:
          break;
      }
    }
  }

  void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    if (radius <= 0) return;
    final dashes = (radius * 2 * math.pi / 7).clamp(12, 160).round();
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => oldDelegate.controller != controller;
}

/// Body colour follows speed: slow bodies are terracotta, fast ones gold.
Color organismColor(Genome genome, GenomeLimits limits) {
  final t = limits.speed.normalize(genome.speed);
  return Color.lerp(Palette.terracotta, Palette.gold, Curves.easeOut.transform(t))!;
}
