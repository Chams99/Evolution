import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../../sim/organism.dart';
import '../../sim/sample.dart';
import '../theme.dart';
import '../microbes.dart';

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
  const TraitChart({
    super.key,
    required this.samples,
    required this.trait,
    required this.range,
    this.height = 56,
    this.trendOnly = false,
  });

  final List<Sample> samples;
  final Trait trait;
  final TraitRange range;
  final double height;

  /// Scale to the mean alone, without the spread band, so small trends show
  /// clearly in a short sparkline. The starting value is marked with a dotted line.
  final bool trendOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _TraitPainter(samples, trait, range, trendOnly), size: Size.infinite),
    );
  }
}

class _TraitPainter extends CustomPainter {
  _TraitPainter(this.samples, this.trait, this.range, this.trendOnly);

  final List<Sample> samples;
  final Trait trait;
  final TraitRange range;
  final bool trendOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, left: 0, bottomPad: 2);
    if (!trendOnly) plot.drawFrame(canvas, lines: 2);
    final alive = [
      for (final s in samples)
        if (s.population > 0) s,
    ];
    if (alive.length < 2) return;

    final idx = _thinnedIndices(alive.length);
    var low = double.infinity, high = double.negativeInfinity;
    for (final i in idx) {
      final t = alive[i].traits[trait]!;
      low = math.min(low, trendOnly ? t.mean : t.mean - t.deviation);
      high = math.max(high, trendOnly ? t.mean : t.mean + t.deviation);
    }
    final start = alive.first.traits[trait]!.mean;
    if (trendOnly) {
      // At least ±6% of the starting value, so noise does not look like a trend.
      low = math.min(low, start * 0.94);
      high = math.max(high, start * 1.06);
    }
    final pad = math.max((high - low) * 0.15, (range.max - range.min) * 0.02);
    low = math.max(range.min, low - pad);
    high = math.min(range.max, high + pad);
    if (high - low < 1e-9) high = low + 1;

    double norm(double v) => (v - low) / (high - low);
    final color = Palette.trait(trait);

    if (trendOnly) {
      final y = plot.y(norm(start), 1);
      final dash = Paint()
        ..color = Palette.lineStrong
        ..strokeWidth = 1;
      for (var x = plot.left; x < plot.right; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, plot.right), y), dash);
      }
      final values = [for (final i in idx) norm(alive[i].traits[trait]!.mean)];
      final area = Path()..moveTo(plot.x(0, values.length), plot.bottom);
      for (var i = 0; i < values.length; i++) {
        area.lineTo(plot.x(i, values.length), plot.y(values[i], 1));
      }
      area
        ..lineTo(plot.x(values.length - 1, values.length), plot.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      plot.line(canvas, values, 1, color, width: 1.6);
      canvas.drawCircle(
        Offset(plot.x(values.length - 1, values.length), plot.y(values.last, 1)),
        2.6,
        Paint()..color = color,
      );
      return;
    }

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

/// Share of the population held by each family over the run, stacked. When
/// one colour widens until it fills the band, that family has taken over.
class FamiliesChart extends StatelessWidget {
  const FamiliesChart({super.key, required this.samples, this.height = 120});

  final List<Sample> samples;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(painter: _FamiliesPainter(samples), size: Size.infinite),
    );
  }
}

class _FamiliesPainter extends CustomPainter {
  _FamiliesPainter(this.samples);

  final List<Sample> samples;

  static const _tracked = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, left: 0, bottomPad: 14);
    final live = [
      for (final s in samples)
        if (s.population > 0) s,
    ];
    if (live.length < 2) {
      plot.drawFrame(canvas, lines: 1);
      return;
    }
    final idx = _thinnedIndices(live.length);

    // Track the families that ever held the largest shares; group the rest.
    final peak = <int, double>{};
    for (final i in idx) {
      final s = live[i];
      s.families.forEach((family, count) {
        final share = count / s.population;
        if (share > (peak[family] ?? 0)) peak[family] = share;
      });
    }
    final tracked =
        (peak.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(_tracked).map((e) => e.key).toList()
          ..sort();

    final layers = <List<double>>[];
    for (final i in idx) {
      final s = live[i];
      var cumulative = 0.0;
      final column = <double>[];
      for (final family in tracked) {
        cumulative += (s.families[family] ?? 0) / s.population;
        column.add(cumulative);
      }
      column.add(1);
      layers.add(column);
    }

    for (var k = tracked.length; k >= 0; k--) {
      final path = Path();
      for (var j = 0; j < idx.length; j++) {
        final p = Offset(plot.x(j, idx.length), plot.y(layers[j][k], 1));
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      for (var j = idx.length - 1; j >= 0; j--) {
        final lower = k == 0 ? 0.0 : layers[j][k - 1];
        path.lineTo(plot.x(j, idx.length), plot.y(lower, 1));
      }
      path.close();
      final color = k == tracked.length ? Palette.raised : familyColor(tracked[k]);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9));
    }
    _text(canvas, '0:00', Offset(plot.left, plot.bottom + 2), Palette.faint);
    _text(
      canvas,
      formatClock(live.last.time),
      Offset(plot.right - 60, plot.bottom + 2),
      Palette.faint,
      alignRight: true,
      width: 60,
    );
  }

  @override
  bool shouldRepaint(_FamiliesPainter old) => true;
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

  /// The part of [limits] the population occupies, padded and snapped to 0.1
  /// so the axes move in steps rather than every frame. Never narrower than
  /// [minSpan], so a clonal population does not fill the whole chart.
  static TraitRange _window(Iterable<double> values, TraitRange limits, {double minSpan = 0.6}) {
    if (values.isEmpty) return limits;
    var low = values.reduce(math.min), high = values.reduce(math.max);
    final pad = math.max((high - low) * 0.15, (minSpan - (high - low)) / 2);
    low = ((low - pad) * 10).floorToDouble() / 10;
    high = ((high + pad) * 10).ceilToDouble() / 10;
    return TraitRange(math.max(limits.min, low), math.min(limits.max, high));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _Plot(size, left: 26, bottomPad: 16);
    plot.drawFrame(canvas, lines: 4, verticals: 4);
    final speedAxis = _window(organisms.map((o) => o.genome.speed), limits.speed);
    final sizeAxis = _window(organisms.map((o) => o.genome.size), limits.size);
    final dot = Paint();
    for (final o in organisms) {
      final p = Offset(
        plot.x(speedAxis.normalize(o.genome.speed), 1, fraction: true),
        plot.y(sizeAxis.normalize(o.genome.size), 1),
      );
      dot.color = familyColor(o.family).withValues(alpha: 0.45 + 0.55 * limits.sense.normalize(o.genome.sense));
      canvas.drawCircle(p, 2.8, dot);
    }
    final pick = selected;
    if (pick != null && pick.alive) {
      final p = Offset(
        plot.x(speedAxis.normalize(pick.genome.speed), 1, fraction: true),
        plot.y(sizeAxis.normalize(pick.genome.size), 1),
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
    _text(canvas, v(speedAxis.min), Offset(plot.left, plot.bottom + 3), Palette.faint);
    _text(canvas, 'SPEED', Offset(plot.left + plot.width / 2 - 14, plot.bottom + 3), Palette.faint);
    _text(
      canvas,
      v(speedAxis.max),
      Offset(plot.right - 30, plot.bottom + 3),
      Palette.faint,
      alignRight: true,
      width: 30,
    );
    _text(canvas, v(sizeAxis.max), Offset(0, plot.top - 2), Palette.faint);
    _text(canvas, v(sizeAxis.min), Offset(0, plot.bottom - 12), Palette.faint);
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
