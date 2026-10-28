import 'package:flutter/foundation.dart';

import '../sim/genome.dart';
import '../sim/world.dart';
import '../sim/world_config.dart';
import 'lab_controller.dart';

/// One thing the user changes in the treated drop. Everything else, seed
/// included, stays as in the control.
enum Treatment {
  predators(
    'Add predators',
    'Big microbes can engulf ones 1.3× smaller.',
    'with predators',
    'Being bigger lets a microbe engulf others and avoid being engulfed, so larger cells leave more daughters.',
  ),
  noVariation(
    'Remove variation',
    'Every founder is identical and daughters are exact copies.',
    'without variation',
    'Selection can only choose between differences. With every microbe identical, there is nothing to choose '
        'between, so the traits stay where they started while the control keeps changing.',
  ),
  fastMutation(
    'Speed up mutation',
    'Daughters differ from their parent 2.5× as much.',
    'with faster mutation',
    'More variation gives selection more to choose from, so whatever pays off spreads faster.',
  ),
  shortLives(
    'Shorten lifespans',
    'Microbes die of old age after 50 seconds instead of 120.',
    'with short lives',
    'When everyone dies young, only microbes that find food fast enough to divide in time leave daughters.',
  ),
  moreAlgae(
    'Double the algae',
    'Algae grow twice as fast.',
    'with double the algae',
    'Plenty of food means almost everyone divides, so selection is weak and the outcome depends a lot on luck.',
  );

  const Treatment(this.title, this.detail, this.phrase, this.why);

  final String title;
  final String detail;

  /// Completes "average size ... ": "with predators".
  final String phrase;

  /// The usual explanation, shown with the result.
  final String why;

  WorldConfig apply(WorldConfig config) => switch (this) {
    Treatment.predators => config.copyWith(predation: true),
    Treatment.noVariation => config.copyWith(mutationStrength: 0, founderVariation: 0),
    Treatment.fastMutation => config.copyWith(mutationStrength: config.mutationStrength * 2.5),
    Treatment.shortLives => config.copyWith(lifespan: 50),
    Treatment.moreAlgae => config.copyWith(foodPerSecond: config.foodPerSecond * 2),
  };
}

enum Direction {
  higher('higher'),
  lower('lower'),
  same('about the same');

  const Direction(this.label);

  final String label;
}

/// What one run found.
class ExperimentResult {
  const ExperimentResult({
    required this.seed,
    required this.control,
    required this.treated,
    required this.observed,
    required this.confirmed,
  });

  final int seed;

  /// Average of the predicted trait over the last 30 simulated seconds, or
  /// null when that drop died out.
  final double? control;
  final double? treated;
  final Direction? observed;
  final bool confirmed;

  double get change => control == null || treated == null ? 0 : treated! / control! - 1;
}

/// A controlled experiment: two drops from the same seed, one of them with
/// the user's change, run side by side for [duration] simulated seconds.
class Experiment extends ChangeNotifier {
  Experiment({this.treatment = Treatment.predators, this.trait = Trait.size, this.direction = Direction.higher});

  /// Long enough for the reliable effects to show in every seed tried (see the tests).
  static const double duration = 480;

  /// Differences smaller than this count as "about the same".
  static const double margin = 0.05;

  /// Simulated speed while running.
  static const int speed = 8;

  Treatment treatment;
  Trait trait;
  Direction direction;

  LabController? control;
  LabController? treated;
  int seed = 1;
  final List<ExperimentResult> results = [];

  bool get running => control != null && !done;
  bool get done => results.length > _resultsAtStart && control != null;
  int _resultsAtStart = 0;

  double get elapsed => control?.world.seconds ?? 0;

  void choose({Treatment? treatment, Trait? trait, Direction? direction}) {
    this.treatment = treatment ?? this.treatment;
    this.trait = trait ?? this.trait;
    this.direction = direction ?? this.direction;
    results.clear();
    notifyListeners();
  }

  /// Starts a run. [nextSeed] repeats the same experiment on a different drop.
  void start({bool nextSeed = false}) {
    if (nextSeed) seed++;
    _dispose();
    final base = Preset.pond.config.copyWith(seed: seed);
    control = LabController(seed: seed)..setSpeed(speed);
    treated = LabController(seed: seed)
      ..restart(config: treatment.apply(base))
      ..setSpeed(speed);
    _resultsAtStart = results.length;
    notifyListeners();
  }

  /// Back to choosing what to test.
  void reset() {
    _dispose();
    results.clear();
    notifyListeners();
  }

  void advance(Duration delta) {
    final a = control, b = treated;
    if (a == null || b == null || done) return;
    a.advance(delta);
    b.advance(delta);
    if (a.world.seconds >= duration || a.world.extinct || b.world.extinct) _finish();
  }

  /// Runs the rest of the experiment at once.
  void finishNow() {
    final a = control, b = treated;
    if (a == null || b == null || done) return;
    a.fastForward(duration - a.world.seconds);
    b.fastForward(duration - b.world.seconds);
    _finish();
  }

  void _finish() {
    final a = control!, b = treated!;
    a.pause();
    b.pause();
    final c = _tailMean(a.world), t = _tailMean(b.world);
    Direction? observed;
    if (c != null && t != null) {
      final change = t / c - 1;
      observed = change > margin
          ? Direction.higher
          : change < -margin
          ? Direction.lower
          : Direction.same;
    }
    results.add(
      ExperimentResult(seed: seed, control: c, treated: t, observed: observed, confirmed: observed == direction),
    );
    notifyListeners();
  }

  double? _tailMean(World world) {
    if (world.extinct) return null;
    final recent = world.history.length > 30 ? world.history.sublist(world.history.length - 30) : world.history;
    return recent.fold<double>(0, (sum, s) => sum + s.traits[trait]!.mean) / recent.length;
  }

  void _dispose() {
    control?.dispose();
    treated?.dispose();
    control = null;
    treated = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }
}
