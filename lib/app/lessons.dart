import '../sim/genome.dart';
import '../sim/world.dart';
import '../sim/world_config.dart';

class LessonProgress {
  const LessonProgress(this.value, this.label);

  /// From 0 to 1. The lesson is complete at 1.
  final double value;
  final String label;

  bool get done => value >= 1;
}

/// A guided experiment: a question, a world set up to answer it, something to
/// watch, a goal the run has to reach, and the explanation once it does.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.question,
    required this.config,
    required this.watch,
    required this.explanation,
    required this.evaluate,
    this.preset,
    this.usesMeteor = false,
  });

  final String id;
  final String title;
  final String question;
  final WorldConfig config;
  final Preset? preset;
  final String watch;
  final String explanation;
  final bool usesMeteor;

  /// Reads the world and returns progress. [memory] survives between calls
  /// within one attempt, for goals that happen in stages.
  final LessonProgress Function(World world, Map<String, double> memory) evaluate;
}

double _change(World world, Trait trait) {
  final start = world.history.first.traits[trait]!.mean;
  final now = world.history.last.traits[trait]!.mean;
  return start == 0 ? 0 : now / start - 1;
}

String _percent(double value) => '${value >= 0 ? '+' : ''}${(value * 100).round()}%';

final lessons = <Lesson>[
  Lesson(
    id: 'fastest',
    title: 'Survival of the fastest',
    question: 'Algae go to whoever reaches them first. What happens to swimming speed over many generations?',
    preset: Preset.bloom,
    config: Preset.bloom.config.copyWith(seed: 2),
    watch: 'Watch the Speed card under the drop, and the tails (flagella) getting longer and faster.',
    explanation:
        'Faster microbes reach algae first, fill up sooner and divide more often. Their daughters inherit the '
        'speed, so each generation starts a little faster. Nobody decides to get faster: slower lines simply '
        'leave fewer descendants. Swimming costs energy with the square of speed, which is what stops the rise.',
    evaluate: (world, _) {
      final change = _change(world, Trait.speed);
      return LessonProgress(change / 0.3, 'Average speed ${_percent(change)} of the +30% goal');
    },
  ),
  Lesson(
    id: 'seasons',
    title: 'Boom and bust',
    question: 'The lamp brightens and dims, and algae grow with it. Does the population just follow the light?',
    preset: Preset.drought,
    config: Preset.drought.config.copyWith(seed: 1),
    watch: 'Watch the drop darken and brighten, and the population line against the shaded light cycle.',
    explanation:
        'The population peaks after the algae do and crashes after them, because microbes live on stored energy '
        'for a while before they starve. That lag turns the light cycle into boom and bust. Each crash is also a '
        'test: whoever burns the least energy is most likely to make it to the next bright spell.',
    evaluate: (world, _) {
      final cycles = world.seconds / world.config.seasonLength;
      return LessonProgress(cycles / 2, 'Light cycle ${cycles.floor().clamp(0, 2) + (cycles >= 2 ? 0 : 1)} of 2');
    },
  ),
  Lesson(
    id: 'arms-race',
    title: 'Arms race',
    question: 'Big microbes can now engulf smaller ones. How do hunters and hunted respond?',
    preset: Preset.hunters,
    config: Preset.hunters.config.copyWith(seed: 2),
    watch: 'Watch the cells grow larger and their red eyespots grow bigger, and the bursts where one is engulfed.',
    explanation:
        'Being big lets you engulf others, so size spreads. Being eaten is the strongest selection there is, so '
        'prey that spot hunters early survive, and eyesight spreads too. Each side raises the bar for the other: '
        'an evolutionary arms race. It only stops when the energy cost of the next step outweighs the gain.',
    evaluate: (world, _) {
      final size = _change(world, Trait.size) / 0.25;
      final sense = _change(world, Trait.sense) / 0.4;
      return LessonProgress(
        size < sense ? size : sense,
        'Size ${_percent(_change(world, Trait.size))} of +25%, sense ${_percent(_change(world, Trait.sense))} of +40%',
      );
    },
  ),
  Lesson(
    id: 'variation',
    title: 'No variation, no evolution',
    question: 'Every microbe in this drop is a perfect clone, and daughters are exact copies. Can anything evolve?',
    config: const WorldConfig(seed: 3, mutationStrength: 0, founderVariation: 0),
    watch: 'Watch the trait cards stay flat. Some families still win, but by luck alone: they are all the same.',
    explanation:
        'Selection can only pick between differences. With identical clones and no mutation there is nothing '
        'to pick from, so the traits cannot move however long you wait. Variation is the raw material of '
        'evolution, and mutation is what keeps supplying it. Try any other lesson to see the contrast.',
    evaluate: (world, _) {
      final seconds = world.seconds;
      return LessonProgress(seconds / 120, '${seconds.floor()} of 120 seconds observed');
    },
  ),
  Lesson(
    id: 'bottleneck',
    title: 'Bottleneck',
    question: 'A disaster wipes out most of the drop at random. What do the survivors pass on?',
    preset: Preset.temperate,
    config: Preset.temperate.config.copyWith(seed: 4),
    usesMeteor: true,
    watch: 'Fire UV pulses into the crowds, then watch the survivors refill the drop. Look at which colours are left.',
    explanation:
        'UV light does not care about traits: it kills whoever happens to be in the beam. The survivors are a '
        'random sample, so the rebuilt population can drift away from where it was, carries less variety, and '
        'often belongs to just a few families. This founder effect is why small, isolated populations look '
        'different from their ancestors.',
    evaluate: (world, memory) {
      final population = world.organisms.length.toDouble();
      final peak = memory['peak'] ?? population;
      if (!memory.containsKey('low')) {
        memory['peak'] = peak > population ? peak : population;
        if (world.totalStruck > 0 && population <= peak * 0.4) memory['low'] = population;
        final lost = peak == 0 ? 0 : 1 - population / peak;
        return LessonProgress(lost / 0.6 * 0.5, 'Wipe out 60% of the population (${(lost * 100).round()}% so far)');
      }
      final recovered = (population / peak).clamp(0, 1).toDouble();
      return LessonProgress(0.5 + recovered * 0.5, 'Recovering: ${population.round()} of ${peak.round()} microbes');
    },
  ),
];
