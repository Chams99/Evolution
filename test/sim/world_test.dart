import 'package:evolution/sim/genome.dart';
import 'package:evolution/sim/organism.dart';
import 'package:evolution/sim/sample.dart';
import 'package:evolution/sim/world.dart';
import 'package:evolution/sim/world_config.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> fingerprint(World world) => [
  for (final s in world.history) '${s.population}/${s.food}/${s.traits[Trait.speed]!.mean.toStringAsFixed(6)}',
];

void main() {
  test('the same seed replays the same history', () {
    final a = World(const WorldConfig(seed: 9))..step(30 * 120);
    final b = World(const WorldConfig(seed: 9))..step(30 * 120);
    expect(fingerprint(a), fingerprint(b));
  });

  test('different seeds lead to different histories', () {
    final a = World(const WorldConfig(seed: 1))..step(30 * 60);
    final b = World(const WorldConfig(seed: 2))..step(30 * 60);
    expect(fingerprint(a), isNot(fingerprint(b)));
  });

  test('one sample is recorded per simulated second', () {
    final world = World(const WorldConfig())..step(30 * 10);
    expect(world.history.map((s) => s.time), [for (var t = 0; t <= 10; t++) t.toDouble()]);
  });

  test('organisms never leave the world', () {
    final world = World(Preset.bloom.config);
    for (var i = 0; i < 30 * 90; i++) {
      world.step();
      for (final o in world.organisms) {
        expect(o.x, inInclusiveRange(0, world.config.width));
        expect(o.y, inInclusiveRange(0, world.config.height));
      }
    }
  });

  test('every food item is eaten at most once', () {
    final world = World(const WorldConfig(seed: 4));
    var meals = 0;
    for (var i = 0; i < 30 * 60; i++) {
      final before = {for (final o in world.organisms) o.id: o.meals};
      world.step();
      for (final o in world.organisms) {
        meals += o.meals - (before[o.id] ?? 0);
      }
      expect(world.food.where((f) => f.eaten), isEmpty);
    }
    expect(meals, greaterThan(0));
  });

  test('a population without food starves out', () {
    final world = World(const WorldConfig(foodPerSecond: 0, initialPopulation: 10));
    world.food.clear();
    world.step(30 * 600);
    expect(world.extinct, isTrue);
    expect(world.history.last.population, 0);
  });

  test('births pass half the energy to the child and add a generation', () {
    final world = World(const WorldConfig(initialPopulation: 1, foodPerSecond: 0, mutationStrength: 0));
    world.food.clear();
    final parent = world.organisms.single..energy = 1000;
    parent.age = 600;
    world.step();
    expect(world.organisms, hasLength(2));
    final child = world.organisms.firstWhere((o) => o.id != parent.id);
    expect(child.generation, 1);
    expect(child.parentId, parent.id);
    expect(child.genome, parent.genome);
    expect(child.energy, closeTo(parent.energy, 1e-9));
  });

  test('predators eat smaller organisms only when predation is on', () {
    World duel({required bool predation}) {
      final world = World(WorldConfig(initialPopulation: 0, foodPerSecond: 0, predation: predation));
      world.food.clear();
      world.organisms.addAll([
        Organism(id: 100, genome: const Genome(size: 2, speed: 1, sense: 60), x: 300, y: 300, energy: 400, heading: 0),
        Organism(id: 101, genome: const Genome(size: 1, speed: 0.3, sense: 8), x: 312, y: 300, energy: 40, heading: 0),
      ]);
      world.step(30 * 3);
      return world;
    }

    final hunting = duel(predation: true);
    expect(hunting.byId(101), isNull);
    expect(hunting.byId(100)!.kills, 1);

    final peaceful = duel(predation: false);
    expect(peaceful.byId(101), isNotNull);
    expect(peaceful.byId(100)!.kills, 0);
  });

  test('seasons swing the food supply around its average', () {
    final world = World(const WorldConfig(seasonLength: 40, seasonStrength: 0.5));
    final supply = <double>[];
    for (var i = 0; i < 40; i++) {
      world.step(30);
      supply.add(world.foodSupply);
    }
    expect(supply.reduce((a, b) => a > b ? a : b), closeTo(1.5, 0.01));
    expect(supply.reduce((a, b) => a < b ? a : b), closeTo(0.5, 0.01));
  });

  test('scattered food lands near the tap and respects the cap', () {
    final world = World(const WorldConfig(maxFood: 50))..food.clear();
    world.scatterFood(100, 100, count: 80);
    expect(world.food, hasLength(50));
    for (final f in world.food) {
      expect((f.x - 100).abs() <= 16 && (f.y - 100).abs() <= 16, isTrue);
    }
  });

  test('csv export has a header and one row per sample', () {
    final world = World(const WorldConfig())..step(30 * 5);
    final lines = samplesToCsv(world.history).trim().split('\n');
    expect(lines.first, startsWith('time_s,population,food'));
    expect(lines, hasLength(world.history.length + 1));
  });

  group('disasters', () {
    test('a meteor kills everything inside its radius and nothing outside', () {
      final world = World(const WorldConfig(initialPopulation: 0, foodPerSecond: 0))..food.clear();
      world.organisms.addAll([
        Organism(id: 1, genome: const Genome(size: 1, speed: 1, sense: 40), x: 100, y: 100, energy: 50, heading: 0),
        Organism(id: 2, genome: const Genome(size: 1, speed: 1, sense: 40), x: 150, y: 100, energy: 50, heading: 0),
        Organism(id: 3, genome: const Genome(size: 1, speed: 1, sense: 40), x: 400, y: 400, energy: 50, heading: 0),
      ]);
      world.scatterFood(110, 110, count: 5, spread: 5);
      world.scatterFood(500, 500, count: 5, spread: 5);

      expect(world.strike(100, 100, radius: 60), 2);
      expect(world.organisms.map((o) => o.id), [3]);
      expect(world.food, hasLength(5));
      expect(world.totalStruck, 2);
      expect(world.events.where((e) => e.cause == DeathCause.disaster), hasLength(2));
      expect(world.events.last.kind, EventKind.strike);
    });

    test('famine removes most food and food rain adds it back', () {
      final world = World(const WorldConfig(seed: 5, maxFood: 400));
      world.foodRain(count: 200);
      final before = world.food.length;
      final removed = world.famine(share: 0.75);
      expect(removed, greaterThan(before * 0.6));
      expect(world.food.length, before - removed);
    });
  });

  group('selection', () {
    test('needs enough births before it reports anything', () {
      expect(World(const WorldConfig()).selection(Trait.speed), isNull);
    });

    test('is positive when faster parents leave the offspring', () {
      final world = World(const WorldConfig(initialPopulation: 0, foodPerSecond: 0, mutationStrength: 0));
      world.food.clear();
      for (var i = 0; i < 20; i++) {
        final fast = i < 10;
        world.organisms.add(
          Organism(
            id: 1000 + i,
            genome: Genome(size: 1, speed: fast ? 2 : 1, sense: 8),
            x: 40.0 + i * 40,
            y: 300,
            energy: fast ? 1000 : 60,
            heading: 0,
          )..age = 600,
        );
      }
      world.step();
      expect(world.selection(Trait.speed), greaterThan(0.5));
      expect(world.selection(Trait.size), 0);
    });
  });

  test('descendants are traced through every generation', () {
    final world = World(const WorldConfig(initialPopulation: 1, foodPerSecond: 0, mutationStrength: 0));
    world.food.clear();
    final founder = world.organisms.single;
    for (var generation = 0; generation < 3; generation++) {
      for (final o in world.organisms) {
        o
          ..energy = 2000
          ..age = 600;
      }
      world.step();
    }
    expect(world.organisms.length, 8);
    expect(world.livingDescendants(founder.id), 7);
    final grandchild = world.organisms.firstWhere((o) => o.generation == 3);
    expect(world.descendsFrom(grandchild, founder.id), isTrue);
    expect(world.descendsFrom(founder, grandchild.id), isFalse);
    expect(world.events.where((e) => e.kind == EventKind.birth), hasLength(7));
    expect(world.organisms.map((o) => o.family).toSet(), {founder.id});
    final birth = world.events.firstWhere((e) => e.kind == EventKind.birth);
    expect(birth.fromX, isNotNull);
    expect(birth.family, founder.id);
  });

  test('family sizes add up to the population and shrink to a few winners', () {
    final world = World(const WorldConfig(seed: 6))..step(30 * 400);
    final families = world.familySizes;
    expect(families.values.fold<int>(0, (a, b) => a + b), world.organisms.length);
    expect(families.length, lessThan(world.config.initialPopulation));
    expect(world.history.last.families, families);
    final sizes = families.values.toList();
    expect(sizes, [...sizes]..sort((a, b) => b.compareTo(a)));
  });
}
