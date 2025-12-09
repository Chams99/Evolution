# Evolution Game 🧬

A Flutter-based evolution simulation game that allows users to test various evolutionary parameters and watch creatures evolve in real-time.

## Features

- 🧬 **Genetic Evolution**: Creatures evolve over time with DNA-based traits (size, speed, sense)
- 🎯 **Natural Selection**: Food scarcity drives evolutionary pressure
- 📊 **Real-time Statistics**: Track population dynamics and trait evolution
- 🎨 **Beautiful Visualization**: Modern UI with creature trails, sense radius, and energy bars
- ⚙️ **Configurable**: Interactive configuration panel to test various options
- 🎮 **Interactive**: Tap anywhere to add food and influence evolution

## Getting Started

### Prerequisites

- Flutter SDK (3.10.1 or higher)
- Dart SDK

### Installation

1. Clone or navigate to the project directory
2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## How to Play

### Basic Controls

- **Tap anywhere**: Add food at that location
- **Play/Pause**: Control simulation speed
- **Reset**: Start a new simulation with current settings
- **Config**: Open configuration panel to adjust parameters

### Understanding the Simulation

#### Creatures
- **Size**: Affects energy capacity and visual size
- **Speed**: Determines maximum movement speed
- **Sense**: Detection radius for finding food (shown as blue circle)

#### Evolution Mechanics
1. Creatures consume energy based on their traits
2. Larger, faster creatures need more food
3. Creatures reproduce when energy > 80% of maximum
4. Offspring inherit DNA with mutations
5. Food becomes scarcer over time, creating selection pressure

#### Visual Indicators
- **Color**: Red = low energy, Blue = high energy
- **Size**: Larger creatures have more energy capacity
- **Trail**: Shows creature movement path
- **Energy Bar**: Green bar above creature shows energy level
- **Sense Radius**: Blue circle shows food detection range

## Configuration Options

Open the Config panel to adjust:

### Simulation
- **Initial Creatures**: Starting population size (5-50)
- **Duration**: Simulation length in seconds (10-300)

### Food
- **Initial Spawn Chance**: How often food appears initially (0.01-0.5)
- **Min Food Count**: Minimum food items in simulation (1-20)
- **Food Energy Value**: Energy gained from eating (5-50)

### Genetics
- **Mutation Rate**: How much DNA changes during reproduction (0.01-0.5)
- **Size Range**: Maximum creature size (1.0-5.0)
- **Speed Range**: Maximum creature speed (1.0-10.0)
- **Sense Range**: Maximum detection radius (50-300)

### Creature
- **Reproduction Threshold**: Energy % needed to reproduce (0.5-1.0)
- **Energy Cost Multiplier**: How much energy creatures consume (0.0001-0.002)
- **Max Age**: Maximum creature lifespan in frames (600-4800)

## Testing Different Scenarios

### Fast Evolution
- Increase Mutation Rate (0.2-0.3)
- Lower Reproduction Threshold (0.6-0.7)
- Higher Food Energy Value (30-40)

### Survival Challenge
- Lower Initial Spawn Chance (0.05-0.1)
- Higher Energy Cost Multiplier (0.001-0.0015)
- Lower Min Food Count (2-3)

### Size vs Speed Trade-off
- Narrow Size Range (1.0-2.0)
- Wide Speed Range (1.0-8.0)
- Observe which trait becomes dominant

## Statistics Panel

The top-left panel shows:
- **Time**: Elapsed simulation time
- **Population**: Current number of creatures
- **Food**: Current food count
- **Scarcity**: Food scarcity percentage
- **Average Traits**: Mean speed, size, and sense values

## Project Structure

```
lib/
├── main.dart                 # Main app entry point
├── models/
│   ├── creature.dart        # Creature and Food classes
│   ├── dna.dart             # DNA trait system
│   ├── simulation.dart      # Simulation engine
│   ├── simulation_config.dart # Configuration model
│   └── simulation_stats.dart # Statistics tracking
└── widgets/
    ├── creature_painter.dart # Custom painter for visualization
    ├── stats_panel.dart      # Statistics display widget
    └── config_panel.dart     # Configuration UI panel
```

## How It Works

### Evolution Algorithm

1. **Initialization**: Creates creatures with random DNA within initial ranges
2. **Update Loop**: Each frame:
   - Creatures seek food within sense radius
   - Creatures consume energy based on traits
   - Food spawns probabilistically
   - Creatures reproduce when conditions are met
   - Dead creatures are removed
3. **Natural Selection**: Food scarcity increases over time, favoring efficient creatures
4. **Mutation**: Offspring DNA mutates slightly from parent
5. **Statistics**: Data recorded every second for analysis

### Energy System

Energy consumption: `(size³ × speed² × multiplier) + base_cost`

This creates trade-offs:
- Large creatures need more food but have more capacity
- Fast creatures find food faster but consume more energy
- Balanced traits often win in the long run

## Tips for Testing

1. **Start Simple**: Use default settings first to understand the system
2. **Change One Thing**: Adjust one parameter at a time to see effects
3. **Watch Statistics**: Observe how average traits change over time
4. **Experiment**: Try extreme values to see interesting behaviors
5. **Reset Often**: Start fresh simulations to test different configurations

## Future Enhancements

Potential additions:
- Export statistics to CSV
- Graph visualization of trait evolution
- Save/load configurations
- Multiple creature types
- Predator-prey relationships
- Environmental obstacles

## License

This project is open source and available for educational and research purposes.

## Acknowledgments

Inspired by evolution simulations and genetic algorithms. Built with Flutter for cross-platform compatibility.
