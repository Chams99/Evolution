import 'package:evolution/app/experiment.dart';
import 'package:evolution/sim/genome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The effects the experiment screen leads with must hold in every seed tried.
  for (final (treatment, trait, direction) in const [
    (Treatment.predators, Trait.size, Direction.higher),
    (Treatment.noVariation, Trait.speed, Direction.lower),
    (Treatment.fastMutation, Trait.speed, Direction.higher),
  ]) {
    test('${treatment.title}: average ${trait.label.toLowerCase()} ends up ${direction.label}', () {
      final experiment = Experiment(treatment: treatment, trait: trait, direction: direction);
      addTearDown(experiment.dispose);
      for (var run = 0; run < 3; run++) {
        experiment.start(nextSeed: run > 0);
        finish(experiment);
        expect(experiment.results.last.confirmed, isTrue, reason: 'seed ${experiment.seed}');
      }
      expect(experiment.results.map((r) => r.seed), [1, 2, 3]);
    });
  }

  test('both drops start from the same founders and only the treatment differs', () {
    final experiment = Experiment(treatment: Treatment.moreAlgae)..start();
    addTearDown(experiment.dispose);
    final a = experiment.control!.world, b = experiment.treated!.world;
    expect([for (final o in a.organisms) o.x], [for (final o in b.organisms) o.x]);
    expect(b.config.foodPerSecond, a.config.foodPerSecond * 2);
    expect(b.config.seed, a.config.seed);
  });

  test('Finish now runs the rest a slice per frame, then gives the verdict', () {
    final experiment = Experiment()..start();
    addTearDown(experiment.dispose);
    experiment.finishNow();
    expect(experiment.finishing, isTrue);
    experiment.advance(const Duration(milliseconds: 16));
    expect(experiment.elapsed, greaterThan(0));
    expect(experiment.done, isFalse, reason: 'one frame should not run the whole experiment');
    finish(experiment);
    expect(experiment.finishing, isFalse);
    expect(experiment.elapsed, Experiment.duration);
    expect(experiment.results, hasLength(1));
  });

  test('a run finishes on its own after the set duration', () {
    final experiment = Experiment()..start();
    addTearDown(experiment.dispose);
    for (var i = 0; i < 2000 && !experiment.done; i++) {
      experiment.advance(const Duration(milliseconds: 100));
    }
    expect(experiment.done, isTrue);
    expect(experiment.elapsed, greaterThanOrEqualTo(Experiment.duration));
    expect(experiment.control!.playing, isFalse);
  });
}

/// Presses Finish now and plays frames until the verdict is in.
void finish(Experiment experiment) {
  experiment.finishNow();
  for (var i = 0; i < 100000 && experiment.running; i++) {
    experiment.advance(const Duration(milliseconds: 16));
  }
}
