import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../../sim/organism.dart';
import '../../sim/sample.dart';
import '../theme.dart';
import 'field_view.dart';

/// At most this many points are drawn per series; longer runs are thinned.
const _maxPoints = 360;

List<int> _thinnedIndices(int length) {
  if (length <= _maxPoints) return [for (var i = 0; i < length; i++) i];
  final step = (length - 1) / (_maxPoints - 1);
  return [for (var i = 0; i < _maxPoints; i++) (i * step).round()];
}

String formatClock(double seconds) {
  final s = seconds.floor();
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, r = s % 60;
  final mm = m.toString().padLeft(2, '0'), ss = r.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Population and food over the whole run, with the seasonal food supply
/// shaded underneath.
class PopulationChart extends StatelessWidget {
  const PopulationChart({super.key, required this.samples, this.height = 140});

  final List<Sample> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    final latest = samples.isEmpty ? null : samples.last;
    return Semantics(
      label: latest == null ? 'Population chart' : 'Population ${latest.population}, food ${latest.food}',
      child: SizedBox(
        height: height,
        child: CustomPaint(painter: _PopulationPainter(samples), size: Size.infinite),
      ),
    );
  }
}

class _PopulationPainter extends CustomPainter {
  _PopulationPainter(this.samples);

  final List<Sample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, bottomPad: 16);
    plot.drawFrame(canvas);
    if (samples.length < 2) return;

    final idx = _thinnedIndices(samples.length);
    final peak = samples.fold<int>(1, (m, s) => math.max(m, math.max(s.population, s.food)));
    final top = _niceCeiling(peak.toDouble());

    final supply = Path()..moveTo(plot.x(0, idx.length), plot.bottom);
    for (var i = 0; i < idx.length; i++) {
      final v = samples[idx[i]].foodSupply / 2;
      supply.lineTo(plot.x(i, idx.length), plot.y(v, 1));
    }
    supply
      ..lineTo(plot.x(idx.length - 1, idx.length), plot.bottom)
      ..close();
    canvas.drawPath(supply, Paint()..color = Palette.gold.withValues(alpha: 0.07));

    plot.line(canvas, [for (final i in idx) samples[i].food.toDouble()], top, Palette.food, width: 1.2);
    plot.line(canvas, [for (final i in idx) samples[i].population.toDouble()], top, Palette.cream, width: 1.8);
    plot.axisLabels(canvas, top: top.round().toString(), right: formatClock(samples.last.time));
  }

  @override
  bool shouldRepaint(_PopulationPainter old) => true;
}

/// Mean of one trait over time, with a band of one standard deviation.
class TraitChart extends StatelessWidget {
  const TraitChart({super.key, required this.samples, required this.trait, required this.range, this.height = 56});

  final List<Sample> samples;
  final Trait trait;
  final TraitRange range;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _TraitPainter(samples, trait, range), size: Size.infinite),
    );
  }
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.samples, this.trait, this.range);

  final List<Sample> samples;
  final Trait trait;
  final TraitRange range;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, left: 0, bottomPad: 2);
    plot.drawFrame(canvas, lines: 2);
    final alive = [
      for (final s in samples)
        if (s.population > 0) s,
    ];
    if (alive.length < 2) return;

    final idx = _thinnedIndices(alive.length);
    var low = double.infinity, high = double.negativeInfinity;
    for (final i in idx) {
      final t = alive[i].traits[trait]!;
      low = math.min(low, t.mean - t.deviation);
      high = math.max(high, t.mean + t.deviation);
    }
    final pad = math.max((high - low) * 0.15, (range.max - range.min) * 0.02);
    low = math.max(range.min, low - pad);
    high = math.min(range.max, high + pad);
    if (high - low < 1e-9) high = low + 1;

    double norm(double v) => (v - low) / (high - low);
    final color = Palette.trait(trait);

    final band = Path();
    for (var i = 0; i < idx.length; i++) {
      final t = alive[idx[i]].traits[trait]!;
      final p = Offset(plot.x(i, idx.length), plot.y(norm(t.mean + t.deviation), 1));
      i == 0 ? band.moveTo(p.dx, p.dy) : band.lineTo(p.dx, p.dy);
    }
    for (var i = idx.length - 1; i >= 0; i--) {
      final t = alive[idx[i]].traits[trait]!;
      band.lineTo(plot.x(i, idx.length), plot.y(norm(t.mean - t.deviation), 1));
    }
    band.close();
    canvas.drawPath(band, Paint()..color = color.withValues(alpha: 0.14));
    plot.line(canvas, [for (final i in idx) norm(alive[i].traits[trait]!.mean)], 1, color, width: 1.6);
  }

  @override
  bool shouldRepaint(_TraitPainter old) => true;
}

/// Every living organism placed by speed (x) and size (y), shaded by sense.
class TraitScatter extends StatelessWidget {
  const TraitScatter({super.key, required this.organisms, required this.limits, this.selected, this.height = 170});

  final List<Organism> organisms;
  final GenomeLimits limits;
  final Organism? selected;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _ScatterPainter(organisms, limits, selected), size: Size.infinite),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter(this.organisms, this.limits, this.selected);

  final List<Organism> organisms;
  final GenomeLimits limits;
  final Organism? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, left: 26, bottomPad: 16);
    plot.drawFrame(canvas, lines: 4, verticals: 4);
    final dot = Paint();
    for (final o in organisms) {
      final p = Offset(
        plot.x(limits.speed.normalize(o.genome.speed), 1, fraction: true),
        plot.y(limits.size.normalize(o.genome.size), 1),
      );
      dot.color = organismColor(
        o.genome,
        limits,
      ).withValues(alpha: 0.35 + 0.6 * limits.sense.normalize(o.genome.sense));
      canvas.drawCircle(p, 2.6, dot);
    }
    final pick = selected;
    if (pick != null && pick.alive) {
      final p = Offset(
        plot.x(limits.speed.normalize(pick.genome.speed), 1, fraction: true),
        plot.y(limits.size.normalize(pick.genome.size), 1),
      );
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Palette.cream,
      );
    }
    String v(double value) => value.toStringAsFixed(1);
    _text(canvas, v(limits.speed.min), Offset(plot.left, plot.bottom + 3), Palette.faint);
    _text(canvas, 'SPEED', Offset(plot.left + plot.width / 2 - 14, plot.bottom + 3), Palette.faint);
    _text(
      canvas,
      v(limits.speed.max),
      Offset(plot.right - 30, plot.bottom + 3),
      Palette.faint,
      alignRight: true,
      width: 30,
    );
    _text(canvas, v(limits.size.max), Offset(0, plot.top - 2), Palette.faint);
    _text(canvas, v(limits.size.min), Offset(0, plot.bottom - 12), Palette.faint);
    canvas.save();
    canvas.translate(2, plot.top + plot.height / 2 + 12);
    canvas.rotate(-math.pi / 2);
    _text(canvas, 'SIZE', Offset.zero, Palette.faint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => true;
}

/// Shared geometry and styling for the small charts.
class _Plot {
  _Plot(this.size, {this.left = 30, this.bottomPad = 4})
    : top = 4,
      right = size.width - 2,
      bottom = size.height - bottomPad;

  final Size size;
  final double left;
  final double bottomPad;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// X for point [i] of [count], or for a 0..1 fraction when [fraction] is set.
  double x(num i, int count, {bool fraction = false}) {
    if (fraction) return left + width * i;
    return count <= 1 ? left : left + width * i / (count - 1);
  }

  double y(double value, double top) => bottom - height * (value / top).clamp(0, 1);

  void drawFrame(Canvas canvas, {int lines = 3, int verticals = 0}) {
    final paint = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    for (var i = 0; i <= lines; i++) {
      final yy = bottom - height * i / lines;
      canvas.drawLine(Offset(left, yy), Offset(right, yy), paint..color = i == 0 ? Palette.lineStrong : Palette.line);
    }
    for (var i = 1; i < verticals; i++) {
      final xx = left + width * i / verticals;
      canvas.drawLine(Offset(xx, top), Offset(xx, bottom), paint..color = Palette.line);
    }
  }

  void line(Canvas canvas, List<double> values, double top, Color color, {double width = 1.5}) {
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i, values.length), y(values[i], top));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void axisLabels(Canvas canvas, {required String top, required String right}) {
    _text(canvas, top, Offset(0, this.top - 2), Palette.faint);
    _text(canvas, '0', Offset(0, bottom - 12), Palette.faint);
    _text(canvas, '0:00', Offset(left, bottom + 3), Palette.faint);
    _text(canvas, right, Offset(this.right - 60, bottom + 3), Palette.faint, alignRight: true, width: 60);
  }
}

void _text(Canvas canvas, String text, Offset at, Color color, {bool alignRight = false, double? width}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: Styles.label.copyWith(fontSize: 9.5, color: color, fontWeight: FontWeight.w400),
    ),
    textDirection: TextDirection.ltr,
    textAlign: alignRight ? TextAlign.right : TextAlign.left,
  )..layout(minWidth: width ?? 0, maxWidth: width ?? 200);
  painter.paint(canvas, at);
}

double _niceCeiling(double value) {
  if (value <= 10) return 10;
  final magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  for (final step in [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (step * magnitude >= value) return step * magnitude;
  }
  return 10 * magnitude;
}
