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

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.controller, this.hover) : super(repaint: Listenable.merge([controller.frame, hover]));

  final LabController controller;
  final ValueNotifier<Offset?> hover;

  static const _gridStep = 60.0;

  /// Bodies are drawn a little larger than their collision radius so they read at a glance.
  static const _bodyScale = 1.2;
  static const _dry = Color(0xFF17110F);
  static const _lush = Color(0xFF0D1511);

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
      ..color = Palette.cream.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var x = _gridStep; x < config.width; x += _gridStep) {
      canvas.drawLine(Offset(x * scale, 0), Offset(x * scale, size.height), grid);
    }
    for (var y = _gridStep; y < config.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y * scale), Offset(size.width, y * scale), grid);
    }

    _paintScorch(canvas, scale, now);

    final foodGlow = Paint()..color = Palette.food.withValues(alpha: 0.12);
    final foodDot = Paint()..color = Palette.food.withValues(alpha: 0.9);
    final foodRadius = math.max(1.6, 2.2 * scale);
    for (final item in world.food) {
      final c = Offset(item.x * scale, item.y * scale);
      canvas.drawCircle(c, foodRadius * 2.2, foodGlow);
      canvas.drawCircle(c, foodRadius, foodDot);
    }

    if (controller.showSense) {
      final senseFill = Paint()..color = Palette.steel.withValues(alpha: 0.045);
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

    _paintEvents(canvas, scale, now, before: true);

    final body = Paint();
    final glow = Paint();
    final wake = Paint();
    final nucleus = Paint()..color = Palette.cream.withValues(alpha: 0.6);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Palette.ink.withValues(alpha: 0.5);
    final familyRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = Palette.cream.withValues(alpha: 0.75);

    for (final o in world.organisms) {
      final c = Offset(o.x * scale, o.y * scale);
      final r = math.max(2.6, o.radius * scale * _bodyScale);
      final color = organismColor(o.genome, limits);
      final direction = Offset(math.cos(o.heading), math.sin(o.heading));
      final side = Offset(-direction.dy, direction.dx);

      glow.shader = RadialGradient(
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.6));
      canvas.drawCircle(c, r * 2.6, glow);

      // Wake: a teardrop that flows out of the body, longer for faster organisms.
      final length = r * (0.8 + o.genome.speed * 1.1);
      final tip = c - direction * (r + length);
      final back = c - direction * (r + length * 0.45);
      final wakePath = Path()
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
      wake.shader = LinearGradient(
        colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0)],
      ).createShader(Rect.fromPoints(c, tip));
      canvas.drawPath(wakePath, wake);

      body.color = color;
      canvas.drawCircle(c, r, body);
      canvas.drawCircle(c, r, rim);
      canvas.drawCircle(c + direction * (r * 0.35), math.max(1.0, r * 0.3), nucleus);

      if (family.contains(o)) canvas.drawCircle(c, r + 3.5, familyRing);
    }

    _paintEvents(canvas, scale, now, before: false);

    if (selected != null && selected.alive) {
      final c = Offset(selected.x * scale, selected.y * scale);
      final r = math.max(2.6, selected.radius * scale * _bodyScale);
      canvas.drawCircle(c, selected.genome.sense * scale, Paint()..color = Palette.steel.withValues(alpha: 0.06));
      _dashedCircle(
        canvas,
        c,
        selected.genome.sense * scale,
        Paint()
          ..color = Palette.steel.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        c,
        r + 5,
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

  void _paintEvents(Canvas canvas, double scale, int now, {required bool before}) {
    for (final e in controller.world.events) {
      final c = Offset(e.x * scale, e.y * scale);
      switch (e.kind) {
        case EventKind.birth when before:
          final t = (now - e.tick) / 18;
          if (t < 0 || t > 1) continue;
          canvas.drawCircle(
            c,
            (e.size + 3 + 10 * t) * scale,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Palette.cream.withValues(alpha: 0.5 * (1 - t)),
          );
        case EventKind.death when before:
          final t = (now - e.tick) / 30;
          if (t < 0 || t > 1) continue;
          final color = switch (e.cause) {
            DeathCause.predation => Palette.rust,
            DeathCause.disaster => Palette.terracotta,
            _ => Palette.faint,
          };
          canvas.drawCircle(c, e.size * scale * (1 - 0.5 * t), Paint()..color = color.withValues(alpha: 0.6 * (1 - t)));
        case EventKind.strike when !before:
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
        default:
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
