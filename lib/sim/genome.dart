import 'rng.dart';

/// The three heritable traits. Each one helps and costs energy.
enum Trait {
  /// Body size: stores more energy and lets an organism eat smaller ones,
  /// but every movement costs more.
  size('Size'),

  /// Top speed: reaches food first, at a cost that grows with the square.
  speed('Speed'),

  /// Sensing radius: finds food and threats from further away.
  sense('Sense');

  const Trait(this.label);

  final String label;
}

class TraitRange {
  const TraitRange(this.min, this.max);

  final double min;
  final double max;

  double clamp(double value) => value.clamp(min, max).toDouble();

  /// Position of [value] inside the range, from 0 to 1.
  double normalize(double value) => ((value - min) / (max - min)).clamp(0, 1).toDouble();
}

class GenomeLimits {
  const GenomeLimits({
    this.size = const TraitRange(0.4, 3.0),
    this.speed = const TraitRange(0.3, 3.5),
    this.sense = const TraitRange(8, 180),
  });

  final TraitRange size;
  final TraitRange speed;
  final TraitRange sense;

  TraitRange of(Trait trait) => switch (trait) {
    Trait.size => size,
    Trait.speed => speed,
    Trait.sense => sense,
  };
}

/// An immutable set of trait values, passed from parent to offspring.
class Genome {
  const Genome({required this.size, required this.speed, required this.sense});

  final double size;
  final double speed;
  final double sense;

  double operator [](Trait trait) => switch (trait) {
    Trait.size => size,
    Trait.speed => speed,
    Trait.sense => sense,
  };

  /// Copies the genome with independent multiplicative Gaussian noise on each
  /// trait. [strength] is the standard deviation of the relative change.
  Genome mutate(Rng rng, {required double strength, required GenomeLimits limits}) {
    double vary(double value, TraitRange range) {
      if (strength <= 0) return value;
      return range.clamp(value * (1 + rng.gaussian() * strength));
    }

    return Genome(size: vary(size, limits.size), speed: vary(speed, limits.speed), sense: vary(sense, limits.sense));
  }

  @override
  bool operator ==(Object other) =>
      other is Genome && other.size == size && other.speed == speed && other.sense == sense;

  @override
  int get hashCode => Object.hash(size, speed, sense);

  @override
  String toString() =>
      'Genome(size: ${size.toStringAsFixed(2)}, speed: ${speed.toStringAsFixed(2)}, '
      'sense: ${sense.toStringAsFixed(1)})';
}
