import 'genome.dart';

enum DeathCause { starvation, oldAge, predation, disaster }

class Organism {
  Organism({
    required this.id,
    required this.genome,
    required this.x,
    required this.y,
    required this.energy,
    required this.heading,
    this.generation = 0,
    this.parentId,
  });

  /// Radius of a size-1 body, in world units.
  static const double baseRadius = 5;

  final int id;
  final Genome genome;
  final int generation;
  final int? parentId;

  double x;
  double y;
  double heading;
  double energy;

  /// Age in ticks.
  int age = 0;
  int meals = 0;
  int kills = 0;
  int offspring = 0;
  DeathCause? deathCause;

  bool get alive => deathCause == null;

  double get radius => genome.size * baseRadius;
}

class Food {
  Food({required this.x, required this.y, required this.energy});

  final double x;
  final double y;
  final double energy;
  bool eaten = false;
}

enum EventKind { birth, death, strike, famine, rain }

/// Something that happened at a place and time, kept briefly so the view can
/// draw it (birth ripples, death fades, meteor shockwaves).
class WorldEvent {
  const WorldEvent({required this.kind, required this.tick, this.x = 0, this.y = 0, this.size = 0, this.cause});

  final EventKind kind;
  final int tick;
  final double x;
  final double y;

  /// Body radius for births and deaths, blast radius for strikes.
  final double size;
  final DeathCause? cause;
}
