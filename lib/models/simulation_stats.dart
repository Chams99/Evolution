class SimulationStats {
  final List<StatPoint> points = [];

  void record({
    required int time,
    required int population,
    required int foodCount,
    required double avgSpeed,
    required double avgSize,
    required double avgSense,
  }) {
    points.add(StatPoint(
      time: time,
      population: population,
      foodCount: foodCount,
      avgSpeed: avgSpeed,
      avgSize: avgSize,
      avgSense: avgSense,
    ));
  }
}

class StatPoint {
  final int time;
  final int population;
  final int foodCount;
  final double avgSpeed;
  final double avgSize;
  final double avgSense;

  StatPoint({
    required this.time,
    required this.population,
    required this.foodCount,
    required this.avgSpeed,
    required this.avgSize,
    required this.avgSense,
  });
}

