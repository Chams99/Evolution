import 'dart:math' as math;

import 'genome.dart';
import 'organism.dart';
import 'rng.dart';
import 'sample.dart';
import 'spatial_grid.dart';
import 'world_config.dart';

/// The simulation. It has no Flutter dependency: the UI only reads its state
/// and calls [step], so the same rules run in tests, on the web and on phones.
class World {
  World(this.config)
    : _rng = Rng(config.seed),
      _foodGrid = SpatialGrid(width: config.width, height: config.height),
      _organismGrid = SpatialGrid(width: config.width, height: config.height) {
    _populate();
    _record();
  }

  /// Distance covered per tick at speed 1, in world units.
  static const double stride = 1.4;

  /// Largest heading change per tick, in radians.
  static const double maxTurn = 0.3;

  /// Samples kept in memory (one per simulated second).
  static const int historyLimit = 7200;

  final WorldConfig config;
  final Rng _rng;
  final SpatialGrid<Food> _foodGrid;
  final SpatialGrid<Organism> _organismGrid;

  final List<Organism> organisms = [];
  final List<Food> food = [];
  final List<Sample> history = [];

  int tick = 0;
  int _nextId = 0;
  int totalBirths = 0;

  int _births = 0, _starved = 0, _diedOfAge = 0, _eaten = 0;

  double get seconds => tick / config.ticksPerSecond;

  bool get extinct => organisms.isEmpty;

  /// Food supply multiplier for the current point in the season cycle.
  double get foodSupply {
    if (config.seasonStrength <= 0 || config.seasonLength <= 0) return 1;
    final phase = 2 * math.pi * seconds / config.seasonLength;
    return math.max(0, 1 + config.seasonStrength * math.sin(phase));
  }

  int get maxGeneration => organisms.fold(0, (best, o) => math.max(best, o.generation));

  Organism? byId(int? id) {
    if (id == null) return null;
    for (final organism in organisms) {
      if (organism.id == id) return organism;
    }
    return null;
  }

  /// The organism under ([x], [y]), with some slack for small bodies.
  Organism? organismAt(double x, double y, {double tolerance = 8}) {
    Organism? best;
    var bestDistance = double.infinity;
    for (final organism in organisms) {
      final dx = organism.x - x, dy = organism.y - y;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance <= organism.radius + tolerance && distance < bestDistance) {
        best = organism;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Drops a small patch of food around ([x], [y]).
  void scatterFood(double x, double y, {int count = 6, double spread = 16}) {
    for (var i = 0; i < count && food.length < config.maxFood; i++) {
      final angle = _rng.range(0, 2 * math.pi);
      final distance = spread * math.sqrt(_rng.next());
      food.add(
        Food(
          x: (x + math.cos(angle) * distance).clamp(2, config.width - 2).toDouble(),
          y: (y + math.sin(angle) * distance).clamp(2, config.height - 2).toDouble(),
          energy: config.foodEnergy,
        ),
      );
    }
  }

  void step([int ticks = 1]) {
    for (var i = 0; i < ticks && !extinct; i++) {
      _tick();
    }
  }

  void _populate() {
    for (var i = 0; i < config.initialPopulation; i++) {
      final genome = config.founder.mutate(_rng, strength: config.founderVariation, limits: config.limits);
      organisms.add(
        Organism(
          id: _nextId++,
          genome: genome,
          x: _rng.range(20, config.width - 20),
          y: _rng.range(20, config.height - 20),
          energy: reproductionThreshold(genome) * 0.55,
          heading: _rng.range(0, 2 * math.pi),
        ),
      );
    }
    final startingFood = (config.foodPerSecond * 6).round().clamp(0, config.maxFood).toInt();
    for (var i = 0; i < startingFood; i++) {
      _spawnFood();
    }
  }

  void _tick() {
    tick++;
    _growFood();
    _indexWorld();
    _shuffle(organisms);

    for (final organism in organisms) {
      if (!organism.alive) continue;
      _steer(organism);
      _move(organism);
      _feed(organism);
    }

    final newborns = <Organism>[];
    for (final organism in organisms) {
      if (!organism.alive) continue;
      _metabolise(organism);
      if (organism.alive) {
        final child = _maybeReproduce(organism);
        if (child != null) newborns.add(child);
      }
    }

    organisms.removeWhere((o) => !o.alive);
    food.removeWhere((f) => f.eaten);
    organisms.addAll(newborns);

    if (tick % config.ticksPerSecond == 0 || extinct) _record();
  }

  void _growFood() {
    final expected = config.foodPerSecond / config.ticksPerSecond * foodSupply;
    var count = expected.floor();
    if (_rng.chance(expected - count)) count++;
    for (var i = 0; i < count && food.length < config.maxFood; i++) {
      _spawnFood();
    }
  }

  void _spawnFood() {
    food.add(Food(x: _rng.range(6, config.width - 6), y: _rng.range(6, config.height - 6), energy: config.foodEnergy));
  }

  void _indexWorld() {
    _foodGrid.clear();
    for (final item in food) {
      if (!item.eaten) _foodGrid.add(item, item.x, item.y);
    }
    _organismGrid.clear();
    for (final organism in organisms) {
      _organismGrid.add(organism, organism.x, organism.y);
    }
  }

  bool _canEat(Organism hunter, Organism prey) =>
      config.predation && hunter.genome.size >= prey.genome.size * config.predatorRatio;

  /// Flee the nearest threat, otherwise head for the nearest meal, otherwise wander.
  void _steer(Organism organism) {
    final sense = organism.genome.sense;
    Organism? threat;
    var threatDistance = double.infinity;
    Organism? prey;
    var preyDistance = double.infinity;

    if (config.predation) {
      _organismGrid.forEachWithin(organism.x, organism.y, sense, (other, d2) {
        if (identical(other, organism) || !other.alive) return;
        if (_canEat(other, organism) && d2 < threatDistance) {
          threat = other;
          threatDistance = d2;
        } else if (_canEat(organism, other) && d2 < preyDistance) {
          prey = other;
          preyDistance = d2;
        }
      });
    }

    final danger = threat;
    if (danger != null) {
      _turnToward(organism, math.atan2(organism.y - danger.y, organism.x - danger.x));
      return;
    }

    Food? meal;
    var mealDistance = double.infinity;
    _foodGrid.forEachWithin(organism.x, organism.y, sense, (item, d2) {
      if (!item.eaten && d2 < mealDistance) {
        meal = item;
        mealDistance = d2;
      }
    });

    final target = prey;
    final nearestFood = meal;
    if (target != null && preyDistance <= mealDistance) {
      _turnToward(organism, math.atan2(target.y - organism.y, target.x - organism.x));
    } else if (nearestFood != null) {
      _turnToward(organism, math.atan2(nearestFood.y - organism.y, nearestFood.x - organism.x));
    } else {
      organism.heading += _rng.gaussian() * 0.25;
    }
  }

  void _turnToward(Organism organism, double desired) {
    var delta = desired - organism.heading;
    delta = math.atan2(math.sin(delta), math.cos(delta));
    organism.heading += delta.clamp(-maxTurn, maxTurn);
  }

  void _move(Organism organism) {
    final distance = organism.genome.speed * stride;
    organism.x += math.cos(organism.heading) * distance;
    organism.y += math.sin(organism.heading) * distance;

    final r = organism.radius;
    if (organism.x < r || organism.x > config.width - r) {
      organism.x = organism.x.clamp(r, config.width - r).toDouble();
      organism.heading = math.pi - organism.heading;
    }
    if (organism.y < r || organism.y > config.height - r) {
      organism.y = organism.y.clamp(r, config.height - r).toDouble();
      organism.heading = -organism.heading;
    }
  }

  void _feed(Organism organism) {
    final reach = organism.radius + 2;
    Food? bite;
    _foodGrid.forEachWithin(organism.x, organism.y, reach, (item, _) {
      if (bite == null && !item.eaten) bite = item;
    });
    final item = bite;
    if (item != null) {
      item.eaten = true;
      organism.energy += item.energy * _digestion(organism.genome);
      organism.meals++;
    }

    if (!config.predation) return;
    Organism? victim;
    _organismGrid.forEachWithin(organism.x, organism.y, organism.radius + Organism.baseRadius * 3, (other, d2) {
      if (victim != null || identical(other, organism) || !other.alive || !_canEat(organism, other)) return;
      final touch = organism.radius + other.radius;
      if (d2 <= touch * touch) victim = other;
    });
    final prey = victim;
    if (prey != null) {
      prey.deathCause = DeathCause.predation;
      _eaten++;
      organism.energy += prey.energy * 0.6 + config.foodEnergy * prey.genome.size * prey.genome.size * 0.3;
      organism.kills++;
    }
  }

  double _tickCost(Genome g) {
    final mass = g.size * g.size;
    return config.basalCost * mass + config.moveCost * mass * g.speed * g.speed + config.senseCost * g.sense;
  }

  /// Energy at which an organism with genome [g] splits in two.
  double reproductionThreshold(Genome g) => config.reproductionEnergy * g.size * g.size;

  /// Share of a food item a body can use. Bodies below size 1 cannot take in
  /// a whole item, so shrinking is not a free win.
  double _digestion(Genome g) => math.min(1.0, g.size * g.size);

  void _metabolise(Organism organism) {
    organism.age++;
    organism.energy -= _tickCost(organism.genome);
    if (organism.energy <= 0) {
      organism.energy = 0;
      organism.deathCause = DeathCause.starvation;
      _starved++;
    } else if (organism.age >= config.lifespan * config.ticksPerSecond) {
      organism.deathCause = DeathCause.oldAge;
      _diedOfAge++;
    }
  }

  Organism? _maybeReproduce(Organism parent) {
    if (parent.age < config.ticksPerSecond * 2) return null;
    if (parent.energy < reproductionThreshold(parent.genome)) return null;

    final genome = parent.genome.mutate(_rng, strength: config.mutationStrength, limits: config.limits);
    final share = parent.energy / 2;
    parent.energy -= share;
    parent.offspring++;
    _births++;
    totalBirths++;

    final angle = _rng.range(0, 2 * math.pi);
    final gap = parent.radius + genome.size * Organism.baseRadius;
    return Organism(
      id: _nextId++,
      genome: genome,
      x: (parent.x + math.cos(angle) * gap)
          .clamp(genome.size * Organism.baseRadius, config.width - genome.size * Organism.baseRadius)
          .toDouble(),
      y: (parent.y + math.sin(angle) * gap)
          .clamp(genome.size * Organism.baseRadius, config.height - genome.size * Organism.baseRadius)
          .toDouble(),
      energy: share,
      heading: angle,
      generation: parent.generation + 1,
      parentId: parent.id,
    );
  }

  void _shuffle(List<Organism> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _rng.nextInt(i + 1);
      final swap = list[i];
      list[i] = list[j];
      list[j] = swap;
    }
  }

  void _record() {
    history.add(
      Sample(
        time: seconds,
        population: organisms.length,
        food: food.length,
        traits: {for (final trait in Trait.values) trait: TraitSummary.of(organisms.map((o) => o.genome[trait]))},
        births: _births,
        starved: _starved,
        diedOfAge: _diedOfAge,
        eaten: _eaten,
        maxGeneration: maxGeneration,
        foodSupply: foodSupply,
      ),
    );
    if (history.length > historyLimit) history.removeAt(0);
    _births = _starved = _diedOfAge = _eaten = 0;
  }
}
