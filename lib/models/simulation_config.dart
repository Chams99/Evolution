class SimulationConfig {
  // Window settings
  final double windowWidth;
  final double windowHeight;
  final int fps;

  // Simulation settings
  final int initialCreatures;
  final int durationSeconds;

  // Food settings
  final double initialSpawnChance;
  final double minSpawnChance;
  final double scarcityFactor;
  final int minFoodCount;
  final double foodEnergyValue;

  // Creature settings
  final double baseEnergyMultiplier;
  final double maxEnergyMultiplier;
  final double reproductionThreshold;
  final double energySplitOnReproduction;
  final int maxAge;
  final double energyCostMultiplier;
  final double baseEnergyCost;

  // Genetics settings
  final double mutationRate;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final double minSense;
  final double maxSense;
  final double initialMinSize;
  final double initialMaxSize;
  final double initialMinSpeed;
  final double initialMaxSpeed;
  final double initialMinSense;
  final double initialMaxSense;

  SimulationConfig({
    this.windowWidth = 1000,
    this.windowHeight = 800,
    this.fps = 60,
    this.initialCreatures = 10,
    this.durationSeconds = 100,
    this.initialSpawnChance = 0.15,
    this.minSpawnChance = 0.03,
    this.scarcityFactor = 10000,
    this.minFoodCount = 5,
    this.foodEnergyValue = 20,
    this.baseEnergyMultiplier = 100,
    this.maxEnergyMultiplier = 200,
    this.reproductionThreshold = 0.8,
    this.energySplitOnReproduction = 0.5,
    this.maxAge = 2400,
    this.energyCostMultiplier = 0.0005,
    this.baseEnergyCost = 0.05,
    this.mutationRate = 0.1,
    this.minSize = 0.5,
    this.maxSize = 3.0,
    this.minSpeed = 0.5,
    this.maxSpeed = 5.0,
    this.minSense = 10,
    this.maxSense = 200,
    this.initialMinSize = 0.5,
    this.initialMaxSize = 2.0,
    this.initialMinSpeed = 1.0,
    this.initialMaxSpeed = 3.0,
    this.initialMinSense = 20,
    this.initialMaxSense = 100,
  });

  SimulationConfig copyWith({
    double? windowWidth,
    double? windowHeight,
    int? fps,
    int? initialCreatures,
    int? durationSeconds,
    double? initialSpawnChance,
    double? minSpawnChance,
    double? scarcityFactor,
    int? minFoodCount,
    double? foodEnergyValue,
    double? baseEnergyMultiplier,
    double? maxEnergyMultiplier,
    double? reproductionThreshold,
    double? energySplitOnReproduction,
    int? maxAge,
    double? energyCostMultiplier,
    double? baseEnergyCost,
    double? mutationRate,
    double? minSize,
    double? maxSize,
    double? minSpeed,
    double? maxSpeed,
    double? minSense,
    double? maxSense,
    double? initialMinSize,
    double? initialMaxSize,
    double? initialMinSpeed,
    double? initialMaxSpeed,
    double? initialMinSense,
    double? initialMaxSense,
  }) {
    return SimulationConfig(
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      fps: fps ?? this.fps,
      initialCreatures: initialCreatures ?? this.initialCreatures,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      initialSpawnChance: initialSpawnChance ?? this.initialSpawnChance,
      minSpawnChance: minSpawnChance ?? this.minSpawnChance,
      scarcityFactor: scarcityFactor ?? this.scarcityFactor,
      minFoodCount: minFoodCount ?? this.minFoodCount,
      foodEnergyValue: foodEnergyValue ?? this.foodEnergyValue,
      baseEnergyMultiplier: baseEnergyMultiplier ?? this.baseEnergyMultiplier,
      maxEnergyMultiplier: maxEnergyMultiplier ?? this.maxEnergyMultiplier,
      reproductionThreshold:
          reproductionThreshold ?? this.reproductionThreshold,
      energySplitOnReproduction:
          energySplitOnReproduction ?? this.energySplitOnReproduction,
      maxAge: maxAge ?? this.maxAge,
      energyCostMultiplier: energyCostMultiplier ?? this.energyCostMultiplier,
      baseEnergyCost: baseEnergyCost ?? this.baseEnergyCost,
      mutationRate: mutationRate ?? this.mutationRate,
      minSize: minSize ?? this.minSize,
      maxSize: maxSize ?? this.maxSize,
      minSpeed: minSpeed ?? this.minSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      minSense: minSense ?? this.minSense,
      maxSense: maxSense ?? this.maxSense,
      initialMinSize: initialMinSize ?? this.initialMinSize,
      initialMaxSize: initialMaxSize ?? this.initialMaxSize,
      initialMinSpeed: initialMinSpeed ?? this.initialMinSpeed,
      initialMaxSpeed: initialMaxSpeed ?? this.initialMaxSpeed,
      initialMinSense: initialMinSense ?? this.initialMinSense,
      initialMaxSense: initialMaxSense ?? this.initialMaxSense,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'initialCreatures': initialCreatures,
      'initialSpawnChance': initialSpawnChance,
      'minFoodCount': minFoodCount,
      'foodEnergyValue': foodEnergyValue,
      'mutationRate': mutationRate,
      'initialMaxSize': initialMaxSize,
      'initialMaxSpeed': initialMaxSpeed,
      'initialMaxSense': initialMaxSense,
      'reproductionThreshold': reproductionThreshold,
      'energyCostMultiplier': energyCostMultiplier,
      'maxAge': maxAge,
    };
  }

  factory SimulationConfig.fromJson(Map<String, dynamic> json) {
    return SimulationConfig(
      initialCreatures: json['initialCreatures'] as int? ?? 10,
      initialSpawnChance: json['initialSpawnChance'] as double? ?? 0.15,
      minFoodCount: json['minFoodCount'] as int? ?? 5,
      foodEnergyValue: json['foodEnergyValue'] as double? ?? 20,
      mutationRate: json['mutationRate'] as double? ?? 0.1,
      initialMaxSize: json['initialMaxSize'] as double? ?? 2.0,
      initialMaxSpeed: json['initialMaxSpeed'] as double? ?? 3.0,
      initialMaxSense: json['initialMaxSense'] as double? ?? 100,
      reproductionThreshold: json['reproductionThreshold'] as double? ?? 0.8,
      energyCostMultiplier: json['energyCostMultiplier'] as double? ?? 0.0005,
      maxAge: json['maxAge'] as int? ?? 2400,
    );
  }
}
