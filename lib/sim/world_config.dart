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
      founderVariation: founderVariation,
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

/// Starting points that push selection in clearly different directions.
enum Preset {
  temperate('Temperate', 'Steady food and mild seasons. Speed and sense creep up slowly.', WorldConfig()),
  drought(
    'Drought',
    'Scarce food and harsh dry spells. Numbers crash each season and speed stays low.',
    WorldConfig(foodPerSecond: 3.5, seasonStrength: 0.85, seasonLength: 60),
  ),
  bloom(
    'Bloom',
    'Plenty of food. The largest crowds, and speed rises fastest.',
    WorldConfig(foodPerSecond: 14, foodEnergy: 45, seasonStrength: 0.2),
  ),
  hunters(
    'Hunters',
    'Predation on. Size, speed and sense escalate together.',
    WorldConfig(foodPerSecond: 6, initialPopulation: 40, mutationStrength: 0.1, predation: true),
  );

  const Preset(this.label, this.summary, this.config);

  final String label;
  final String summary;
  final WorldConfig config;
}
