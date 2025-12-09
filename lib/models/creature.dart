import 'dart:math';
import 'dart:ui' as ui;
import 'dna.dart';
import 'simulation_config.dart';

class Creature {
  final String id;
  final DNA dna;
  final SimulationConfig config;
  
  double x;
  double y;
  double energy;
  double maxEnergy;
  int age;
  double vx;
  double vy;
  
  final List<ui.Offset> trail = [];
  static const int maxTrailLength = 10;

  Creature({
    required this.id,
    required this.x,
    required this.y,
    required this.dna,
    required this.config,
    double? energy,
    double? maxEnergy,
  }) : energy = energy ?? (config.baseEnergyMultiplier * dna.size),
       maxEnergy = maxEnergy ?? (config.maxEnergyMultiplier * dna.size),
       age = 0,
       vx = 0,
       vy = 0;

  Creature.random({
    required String id,
    required double x,
    required double y,
    required SimulationConfig config,
  }) : id = id,
       x = x,
       y = y,
       dna = DNA.random(
         minSize: config.initialMinSize,
         maxSize: config.initialMaxSize,
         minSpeed: config.initialMinSpeed,
         maxSpeed: config.initialMaxSpeed,
         minSense: config.initialMinSense,
         maxSense: config.initialMaxSense,
       ),
       config = config,
       energy = config.baseEnergyMultiplier * (config.initialMinSize + Random().nextDouble() * (config.initialMaxSize - config.initialMinSize)),
       maxEnergy = config.maxEnergyMultiplier * (config.initialMinSize + Random().nextDouble() * (config.initialMaxSize - config.initialMinSize)),
       age = 0,
       vx = 0,
       vy = 0;

  void update(List<Food> foods, double width, double height) {
    age++;
    
    // Update trail
    trail.add(ui.Offset(x, y));
    if (trail.length > maxTrailLength) {
      trail.removeAt(0);
    }

    // Find nearest food
    Food? nearestFood;
    double nearestDistance = double.infinity;

    for (final food in foods) {
      final dx = food.x - x;
      final dy = food.y - y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance <= dna.sense && distance < nearestDistance) {
        nearestDistance = distance;
        nearestFood = food;
      }
    }

    // Move towards food or wander
    if (nearestFood != null) {
      final dx = nearestFood.x - x;
      final dy = nearestFood.y - y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance > 0) {
        vx = (dx / distance) * dna.speed;
        vy = (dy / distance) * dna.speed;
      }

      // Eat food if close enough
      if (distance < dna.size * 2) {
        energy = min(energy + config.foodEnergyValue, maxEnergy);
        nearestFood.consumed = true;
      }
    } else {
      // Wander randomly
      if (Random().nextDouble() < 0.1) {
        vx = (Random().nextDouble() - 0.5) * dna.speed;
        vy = (Random().nextDouble() - 0.5) * dna.speed;
      }
    }

    // Update position
    x += vx;
    y += vy;

    // Boundary collision
    if (x < dna.size) {
      x = dna.size;
      vx *= -0.5;
    } else if (x > width - dna.size) {
      x = width - dna.size;
      vx *= -0.5;
    }
    if (y < dna.size) {
      y = dna.size;
      vy *= -0.5;
    } else if (y > height - dna.size) {
      y = height - dna.size;
      vy *= -0.5;
    }

    // Consume energy
    final energyCost = (pow(dna.size, 3) * pow(dna.speed, 2) * config.energyCostMultiplier) + config.baseEnergyCost;
    energy = max(0, energy - energyCost);
  }

  bool canReproduce() {
    return energy >= maxEnergy * config.reproductionThreshold && age > 60;
  }

  Creature? reproduce() {
    if (!canReproduce()) return null;

    final newDNA = dna.mutate(
      mutationRate: config.mutationRate,
      minSize: config.minSize,
      maxSize: config.maxSize,
      minSpeed: config.minSpeed,
      maxSpeed: config.maxSpeed,
      minSense: config.minSense,
      maxSense: config.maxSense,
    );

    // Split energy
    energy *= config.energySplitOnReproduction;
    final baseMult = (maxEnergy / dna.size).round();
    final maxMult = baseMult * 2;

    return Creature(
      id: '${id}_child_${DateTime.now().millisecondsSinceEpoch}',
      x: x + (Random().nextDouble() - 0.5) * 20,
      y: y + (Random().nextDouble() - 0.5) * 20,
      dna: newDNA,
      config: config,
      energy: baseMult * newDNA.size,
      maxEnergy: maxMult * newDNA.size,
    );
  }

  bool isDead() {
    return energy <= 0 || age >= config.maxAge;
  }

  double get health => energy / maxEnergy;
}

class Food {
  double x;
  double y;
  bool consumed;

  Food({required this.x, required this.y}) : consumed = false;
}

