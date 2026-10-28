import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../lab_controller.dart';
import '../theme.dart';

/// The world, scaled to fit while keeping its aspect ratio. Tap an organism
/// to inspect it, tap empty ground to drop food.
class FieldView extends StatelessWidget {
  const FieldView({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.config;
    return AspectRatio(
      aspectRatio: config.width / config.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / config.width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                controller.tapField(details.localPosition.dx / scale, details.localPosition.dy / scale),
            child: Semantics(
              label: 'Simulation field. Tap an organism to inspect it, or empty ground to drop food.',
              child: RepaintBoundary(
                child: CustomPaint(painter: _FieldPainter(controller), size: Size.infinite),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter(this.controller) : super(repaint: controller.frame);

  final LabController controller;

  static const _gridStep = 60.0;

  @override
  void paint(Canvas canvas, Size size) {
    final world = controller.world;
    final config = world.config;
    final scale = size.width / config.width;
    final limits = config.limits;

    final frame = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.drawRRect(frame, Paint()..color = Palette.surface);
    canvas.save();
    canvas.clipRRect(frame);

    final grid = Paint()
      ..color = Palette.line.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = _gridStep; x < config.width; x += _gridStep) {
      canvas.drawLine(Offset(x * scale, 0), Offset(x * scale, size.height), grid);
    }
    for (var y = _gridStep; y < config.height; y += _gridStep) {
      canvas.drawLine(Offset(0, y * scale), Offset(size.width, y * scale), grid);
    }

    final foodPaint = Paint()..color = Palette.food.withValues(alpha: 0.85);
    final foodRadius = math.max(1.6, 2.2 * scale);
    for (final item in world.food) {
      canvas.drawCircle(Offset(item.x * scale, item.y * scale), foodRadius, foodPaint);
    }

    final selected = controller.selected;
    final senseFill = Paint()..color = Palette.steel.withValues(alpha: 0.05);
    final senseEdge = Paint()
      ..color = Palette.steel.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (controller.showSense) {
      for (final o in world.organisms) {
        final c = Offset(o.x * scale, o.y * scale);
        canvas.drawCircle(c, o.genome.sense * scale, senseFill);
      }
    }

    final body = Paint();
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Palette.ink.withValues(alpha: 0.6);
    final heading = Paint()
      ..color = Palette.cream.withValues(alpha: 0.55)
      ..strokeWidth = math.max(1, 1.2 * scale)
      ..strokeCap = StrokeCap.round;

    for (final o in world.organisms) {
      final c = Offset(o.x * scale, o.y * scale);
      final r = math.max(2.0, o.radius * scale);
      body.color = organismColor(o.genome, limits);
      canvas.drawCircle(c, r, body);
      canvas.drawCircle(c, r, outline);
      canvas.drawLine(c, c + Offset(math.cos(o.heading), math.sin(o.heading)) * (r + 2.5 * scale), heading);
    }

    if (selected != null && selected.alive) {
      final c = Offset(selected.x * scale, selected.y * scale);
      final r = math.max(2.0, selected.radius * scale);
      canvas.drawCircle(c, selected.genome.sense * scale, senseFill);
      _dashedCircle(canvas, c, selected.genome.sense * scale, senseEdge);
      canvas.drawCircle(
        c,
        r + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Palette.cream,
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
