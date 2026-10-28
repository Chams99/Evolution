import 'dart:math' as math;

import 'genome.dart';

class TraitSummary {
  const TraitSummary({required this.mean, required this.deviation, required this.min, required this.max});

  static const empty = TraitSummary(mean: 0, deviation: 0, min: 0, max: 0);

  factory TraitSummary.of(Iterable<double> values) {
    var count = 0;
    var sum = 0.0, sumSquares = 0.0;
    var low = double.infinity, high = double.negativeInfinity;
    for (final value in values) {
      count++;
      sum += value;
      sumSquares += value * value;
      low = math.min(low, value);
      high = math.max(high, value);
    }
    if (count == 0) return empty;
    final mean = sum / count;
    final variance = math.max(0.0, sumSquares / count - mean * mean);
    return TraitSummary(mean: mean, deviation: math.sqrt(variance), min: low, max: high);
  }

  final double mean;
  final double deviation;
  final double min;
  final double max;
}

/// One reading of the world, taken every simulated second.
class Sample {
  const Sample({
    required this.time,
    required this.population,
    required this.food,
    required this.traits,
    required this.births,
    required this.starved,
    required this.diedOfAge,
    required this.eaten,
    this.struck = 0,
    required this.maxGeneration,
    required this.foodSupply,
  });

  /// Simulated seconds since the start of the run.
  final double time;
  final int population;
  final int food;
  final Map<Trait, TraitSummary> traits;

  /// Events since the previous sample.
  final int births;
  final int starved;
  final int diedOfAge;
  final int eaten;

  /// Killed by meteor strikes.
  final int struck;

  final int maxGeneration;

  /// Seasonal food multiplier at this moment.
  final double foodSupply;
}

/// Run history as CSV, one row per sample.
String samplesToCsv(List<Sample> samples) {
  final buffer = StringBuffer(
    'time_s,population,food,births,starved,died_of_age,eaten,struck,max_generation,food_supply,'
    'size_mean,size_sd,speed_mean,speed_sd,sense_mean,sense_sd\n',
  );
  String f(double value, [int digits = 3]) => value.toStringAsFixed(digits);
  for (final s in samples) {
    final size = s.traits[Trait.size]!, speed = s.traits[Trait.speed]!, sense = s.traits[Trait.sense]!;
    buffer.writeln(
      [
        f(s.time, 0),
        s.population,
        s.food,
        s.births,
        s.starved,
        s.diedOfAge,
        s.eaten,
        s.struck,
        s.maxGeneration,
        f(s.foodSupply),
        f(size.mean),
        f(size.deviation),
        f(speed.mean),
        f(speed.deviation),
        f(sense.mean, 2),
        f(sense.deviation, 2),
      ].join(','),
    );
  }
  return buffer.toString();
}
