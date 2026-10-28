import 'package:evolution/sim/genome.dart';
import 'package:evolution/sim/rng.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const limits = GenomeLimits();
  const genome = Genome(size: 1, speed: 1, sense: 40);

  test('mutation with zero strength returns an identical genome', () {
    expect(genome.mutate(Rng(1), strength: 0, limits: limits), genome);
  });

  test('mutation is reproducible for a given seed', () {
    final a = genome.mutate(Rng(42), strength: 0.2, limits: limits);
    final b = genome.mutate(Rng(42), strength: 0.2, limits: limits);
    expect(a, b);
    expect(a, isNot(genome));
  });

  test('mutated traits always stay inside their limits', () {
    final rng = Rng(7);
    var current = genome;
    for (var i = 0; i < 5000; i++) {
      current = current.mutate(rng, strength: 0.6, limits: limits);
      for (final trait in Trait.values) {
        final range = limits.of(trait);
        expect(current[trait], inInclusiveRange(range.min, range.max));
      }
    }
  });

  test('gaussian samples have roughly zero mean and unit variance', () {
    final rng = Rng(3);
    const n = 20000;
    var sum = 0.0, squares = 0.0;
    for (var i = 0; i < n; i++) {
      final g = rng.gaussian();
      sum += g;
      squares += g * g;
    }
    expect(sum / n, closeTo(0, 0.03));
    expect(squares / n, closeTo(1, 0.05));
  });

  test('trait ranges normalize to 0..1', () {
    const range = TraitRange(10, 20);
    expect(range.normalize(10), 0);
    expect(range.normalize(15), 0.5);
    expect(range.normalize(40), 1);
  });
}
