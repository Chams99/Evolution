// Runs each preset headless and prints how the population and traits move.
// Useful when tuning the energy model: dart run tool/balance.dart [seconds]
// ignore_for_file: avoid_print
import 'package:evolution/sim/genome.dart';
import 'package:evolution/sim/world.dart';
import 'package:evolution/sim/world_config.dart';

void main(List<String> args) {
  final seconds = args.isEmpty ? 600 : int.parse(args.first);
  for (final preset in Preset.values) {
    for (final seed in [1, 2, 3]) {
      final world = World(preset.config.copyWith(seed: seed));
      final watch = Stopwatch()..start();
      final line = StringBuffer('${preset.label.padRight(10)} seed $seed |');
      for (var t = 0; t < seconds; t += seconds ~/ 6) {
        world.step(world.config.ticksPerSecond * (seconds ~/ 6));
        final s = world.history.last;
        line.write(
          ' ${s.population.toString().padLeft(3)}'
          ' [${s.traits[Trait.size]!.mean.toStringAsFixed(2)}'
          ' ${s.traits[Trait.speed]!.mean.toStringAsFixed(2)}'
          ' ${s.traits[Trait.sense]!.mean.toStringAsFixed(0)}]',
        );
        if (world.extinct) {
          line.write(' extinct at ${world.seconds.toStringAsFixed(0)}s');
          break;
        }
      }
      line.write(' | gen ${world.history.last.maxGeneration} | ${watch.elapsedMilliseconds} ms');
      print(line);
    }
  }
}
