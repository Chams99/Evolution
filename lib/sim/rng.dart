import 'dart:math' as math;

/// Seeded random source. Every random decision in a run goes through one
/// instance, so the same seed always replays the same history.
class Rng {
  Rng(int seed) : _random = math.Random(seed);

  final math.Random _random;
  double? _spareGaussian;

  double next() => _random.nextDouble();

  int nextInt(int max) => _random.nextInt(max);

  bool chance(double probability) => _random.nextDouble() < probability;

  double range(double min, double max) => min + (max - min) * next();

  /// Standard normal sample (Box-Muller, with the second value cached).
  double gaussian() {
    final spare = _spareGaussian;
    if (spare != null) {
      _spareGaussian = null;
      return spare;
    }
    double u;
    do {
      u = next();
    } while (u == 0);
    final v = next();
    final radius = math.sqrt(-2 * math.log(u));
    _spareGaussian = radius * math.sin(2 * math.pi * v);
    return radius * math.cos(2 * math.pi * v);
  }
}
