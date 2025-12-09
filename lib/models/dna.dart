import 'dart:math';

class DNA {
  final double size;
  final double speed;
  final double sense;

  DNA({
    required this.size,
    required this.speed,
    required this.sense,
  });

  DNA.random({
    required double minSize,
    required double maxSize,
    required double minSpeed,
    required double maxSpeed,
    required double minSense,
    required double maxSense,
  }) : size = minSize + Random().nextDouble() * (maxSize - minSize),
       speed = minSpeed + Random().nextDouble() * (maxSpeed - minSpeed),
       sense = minSense + Random().nextDouble() * (maxSense - minSense);

  DNA mutate({
    required double mutationRate,
    required double minSize,
    required double maxSize,
    required double minSpeed,
    required double maxSpeed,
    required double minSense,
    required double maxSense,
  }) {
    final random = Random();
    return DNA(
      size: (size + (random.nextDouble() - 0.5) * mutationRate)
          .clamp(minSize, maxSize),
      speed: (speed + (random.nextDouble() - 0.5) * mutationRate)
          .clamp(minSpeed, maxSpeed),
      sense: (sense + (random.nextDouble() - 0.5) * mutationRate * 20)
          .clamp(minSense, maxSense),
    );
  }

  DNA copyWith({
    double? size,
    double? speed,
    double? sense,
  }) {
    return DNA(
      size: size ?? this.size,
      speed: speed ?? this.speed,
      sense: sense ?? this.sense,
    );
  }
}

