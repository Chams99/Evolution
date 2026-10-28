import 'genome.dart';

/// Everything that defines a run. Two worlds with equal configs (including
/// [seed]) produce identical histories.
class WorldConfig {
  const WorldConfig({
    this.seed = 1,
    this.width = 960,
    this.height = 600,
    this.ticksPerSecond = 30,
    this.initialPopulation = 28,
    this.founder = const Genome(size: 1.0, speed: 1.0, sense: 40),
    this.founderVariation = 0.12,
    this.foodPerSecond = 7,
    this.foodEnergy = 55,
    this.maxFood = 240,
    this.seasonLength = 80,
    this.seasonStrength = 0.5,
    this.mutationStrength = 0.07,
    this.predation = false,
    this.predatorRatio = 1.3,
    this.basalCost = 0.045,
    this.moveCost = 0.028,
    this.senseCost = 0.0007,
    this.reproductionEnergy = 150,
    this.lifespan = 120,
    this.limits = const GenomeLimits(),
  });

  /// Seed for every random decision in the run.
  final int seed;

  /// World size in simulation units. The view scales it to fit the screen.
  final double width;
  final double height;

  /// Simulation steps per simulated second.
  final int ticksPerSecond;

  final int initialPopulation;

  /// Genome of the founding population, before [founderVariation] is applied.
  final Genome founder;
  final double founderVariation;

  /// Average food items added per simulated second, before seasons.
  final double foodPerSecond;
  final double foodEnergy;
  final int maxFood;

  /// Length of one full season cycle, in simulated seconds.
  final double seasonLength;

  /// How much the food supply swings over a season, from 0 (none) to 1.
  final double seasonStrength;

  /// Standard deviation of the relative trait change at each birth.
  final double mutationStrength;

  /// Whether organisms that are [predatorRatio] times larger can eat others.
  final bool predation;
  final double predatorRatio;

  /// Energy cost per tick: basal * size² + move * size² * speed² + sense * radius.
  final double basalCost;
  final double moveCost;
  final double senseCost;

  /// Energy needed to split in two, scaled by size².
  final double reproductionEnergy;

  /// Maximum age, in simulated seconds.
  final double lifespan;

  final GenomeLimits limits;

  WorldConfig copyWith({
    int? seed,
    int? initialPopulation,
    double? founderVariation,
    double? foodPerSecond,
    double? foodEnergy,
    double? seasonLength,
    double? seasonStrength,
    double? mutationStrength,
    bool? predation,
    double? lifespan,
  }) {
    return WorldConfig(
      seed: seed ?? this.seed,
      width: width,
      height: height,
      ticksPerSecond: ticksPerSecond,
      initialPopulation: initialPopulation ?? this.initialPopulation,
      founder: founder,
      founderVariation: founderVariation ?? this.founderVariation,
      foodPerSecond: foodPerSecond ?? this.foodPerSecond,
      foodEnergy: foodEnergy ?? this.foodEnergy,
      maxFood: maxFood,
      seasonLength: seasonLength ?? this.seasonLength,
      seasonStrength: seasonStrength ?? this.seasonStrength,
      mutationStrength: mutationStrength ?? this.mutationStrength,
      predation: predation ?? this.predation,
      predatorRatio: predatorRatio,
      basalCost: basalCost,
      moveCost: moveCost,
      senseCost: senseCost,
      reproductionEnergy: reproductionEnergy,
      lifespan: lifespan ?? this.lifespan,
      limits: limits,
    );
  }
}

/// Starting points that push selection in clearly different directions. Each
/// one is framed as a sample of water under the microscope.
enum Preset {
  pond(
    'Pond',
    'POND WATER',
    'A drop from a healthy pond. Steady algae and a gentle light cycle. Speed and sense creep up slowly.',
    WorldConfig(),
  ),
  puddle(
    'Drying puddle',
    'DRYING PUDDLE',
    'Scarce algae and long dim spells. Numbers crash every cycle, and running costs too much to get faster.',
    WorldConfig(foodPerSecond: 3.5, seasonStrength: 0.85, seasonLength: 60),
  ),
  bloom(
    'Algae bloom',
    'NUTRIENT-RICH POND',
    'Algae everywhere. The largest crowds, and speed rises fastest as everyone races for the next cell.',
    WorldConfig(foodPerSecond: 14, foodEnergy: 45, seasonStrength: 0.2),
  ),
  predators(
    'Predators',
    'POND WITH PREDATORS',
    'Big microbes can engulf smaller ones. Size, speed and eyesight escalate together.',
    WorldConfig(foodPerSecond: 6, initialPopulation: 40, mutationStrength: 0.1, predation: true),
  );

  const Preset(this.label, this.sample, this.summary, this.config);

  final String label;

  /// Label of the sample on the microscope overlay.
  final String sample;
  final String summary;
  final WorldConfig config;
}
