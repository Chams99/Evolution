import 'package:flutter/material.dart';
import '../models/simulation_config.dart';

class ConfigPanel extends StatefulWidget {
  final SimulationConfig config;
  final Function(SimulationConfig) onConfigChanged;

  const ConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  late SimulationConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Configuration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection('Simulation', Icons.play_circle_outline, [
              _buildSlider(
                'Initial Creatures',
                _config.initialCreatures.toDouble(),
                5,
                50,
                (v) => _updateConfig(
                  _config.copyWith(initialCreatures: v.round()),
                ),
              ),
            ]),
            _buildSection('Food', Icons.restaurant, [
              _buildSlider(
                'Initial Spawn Chance',
                _config.initialSpawnChance,
                0.01,
                0.5,
                (v) => _updateConfig(_config.copyWith(initialSpawnChance: v)),
              ),
              _buildSlider(
                'Min Food Count',
                _config.minFoodCount.toDouble(),
                1,
                20,
                (v) => _updateConfig(_config.copyWith(minFoodCount: v.round())),
              ),
              _buildSlider(
                'Food Energy Value',
                _config.foodEnergyValue,
                5,
                50,
                (v) => _updateConfig(_config.copyWith(foodEnergyValue: v)),
              ),
            ]),
            _buildSection('Genetics', Icons.science, [
              _buildSlider(
                'Mutation Rate',
                _config.mutationRate,
                0.01,
                0.5,
                (v) => _updateConfig(_config.copyWith(mutationRate: v)),
              ),
              _buildSlider(
                'Initial Size',
                _config.initialMaxSize,
                0.5,
                3.0,
                (v) => _updateConfig(_config.copyWith(initialMaxSize: v)),
              ),
              _buildSlider(
                'Initial Speed',
                _config.initialMaxSpeed,
                1.0,
                5.0,
                (v) => _updateConfig(_config.copyWith(initialMaxSpeed: v)),
              ),
              _buildSlider(
                'Initial Sense',
                _config.initialMaxSense,
                20,
                150,
                (v) => _updateConfig(_config.copyWith(initialMaxSense: v)),
              ),
            ]),
            _buildSection('Creature', Icons.pets, [
              _buildSlider(
                'Reproduction Threshold',
                _config.reproductionThreshold,
                0.5,
                1.0,
                (v) =>
                    _updateConfig(_config.copyWith(reproductionThreshold: v)),
              ),
              _buildSlider(
                'Energy Cost Multiplier',
                _config.energyCostMultiplier,
                0.0001,
                0.002,
                (v) => _updateConfig(_config.copyWith(energyCostMultiplier: v)),
              ),
              _buildSlider(
                'Max Age',
                _config.maxAge.toDouble(),
                600,
                4800,
                (v) => _updateConfig(_config.copyWith(maxAge: v.round())),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  void _updateConfig(SimulationConfig newConfig) {
    setState(() {
      _config = newConfig;
    });
    widget.onConfigChanged(newConfig);
  }
}
