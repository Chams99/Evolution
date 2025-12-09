import 'dart:math';
import 'creature.dart';
import 'simulation_config.dart';
import 'simulation_stats.dart';

class Simulation {
  final SimulationConfig config;
  final List<Creature> creatures = [];
  final List<Food> foods = [];
  final SimulationStats stats = SimulationStats();
  
  int frameCount = 0;
  bool isPaused = false;
  double foodSpawnChance = 0.15;
  double scarcity = 0;

  Simulation(this.config) {
    _initialize();
  }

  void _initialize() {
    // Create initial creatures
    final random = Random();
    for (int i = 0; i < config.initialCreatures; i++) {
      creatures.add(Creature.random(
        id: 'creature_$i',
        x: random.nextDouble() * config.windowWidth,
        y: random.nextDouble() * config.windowHeight,
        config: config,
      ));
    }

    // Create initial food
    for (int i = 0; i < config.minFoodCount; i++) {
      foods.add(Food(
        x: random.nextDouble() * config.windowWidth,
        y: random.nextDouble() * config.windowHeight,
      ));
    }
  }

  void update() {
    if (isPaused) return;

    frameCount++;
    final time = frameCount ~/ config.fps;

    // Update scarcity
    scarcity = min(1.0, frameCount / config.scarcityFactor);
    foodSpawnChance = config.initialSpawnChance - 
        (config.initialSpawnChance - config.minSpawnChance) * scarcity;

    // Spawn food
    if (foods.length < config.minFoodCount || Random().nextDouble() < foodSpawnChance) {
      foods.add(Food(
        x: Random().nextDouble() * config.windowWidth,
        y: Random().nextDouble() * config.windowHeight,
      ));
    }

    // Update creatures
    final newCreatures = <Creature>[];
    for (final creature in creatures) {
      creature.update(foods, config.windowWidth, config.windowHeight);

      // Check reproduction
      final offspring = creature.reproduce();
      if (offspring != null) {
        newCreatures.add(offspring);
      }
    }

    // Remove dead creatures and consumed food
    creatures.removeWhere((c) => c.isDead());
    foods.removeWhere((f) => f.consumed);

    // Add new creatures
    creatures.addAll(newCreatures);

    // Record stats every second
    if (frameCount % config.fps == 0) {
      if (creatures.isNotEmpty) {
        final avgSpeed = creatures.map((c) => c.dna.speed).reduce((a, b) => a + b) / creatures.length;
        final avgSize = creatures.map((c) => c.dna.size).reduce((a, b) => a + b) / creatures.length;
        final avgSense = creatures.map((c) => c.dna.sense).reduce((a, b) => a + b) / creatures.length;

        stats.record(
          time: time,
          population: creatures.length,
          foodCount: foods.length,
          avgSpeed: avgSpeed,
          avgSize: avgSize,
          avgSense: avgSense,
        );
      }
    }
  }

  void addFood(double x, double y) {
    foods.add(Food(x: x, y: y));
  }

  void reset() {
    creatures.clear();
    foods.clear();
    stats.points.clear();
    frameCount = 0;
    foodSpawnChance = config.initialSpawnChance;
    scarcity = 0;
    _initialize();
  }
}

