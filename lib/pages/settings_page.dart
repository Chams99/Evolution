import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/simulation_config.dart';

class SettingsPage extends StatefulWidget {
  final SimulationConfig initialConfig;
  final Function(SimulationConfig) onConfigSaved;

  const SettingsPage({
    super.key,
    required this.initialConfig,
    required this.onConfigSaved,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late SimulationConfig config;

  @override
  void initState() {
    super.initState();
    config = widget
        .initialConfig; // Initialize immediately to prevent LateInitializationError
    _loadConfig(); // Then load saved config asynchronously
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('simulation_config');

    if (configJson != null) {
      try {
        final Map<String, dynamic> json = jsonDecode(configJson);
        setState(() {
          config = SimulationConfig.fromJson(json);
        });
      } catch (e) {
        // Keep the initial config if there's an error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(onPressed: _saveSettings, child: const Text('Save')),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              const Color(0xFF2A2A72), // Deep Blue/Purple
              Colors.black,
            ],
            stops: const [0.0, 0.8],
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('Simulation', [
                  _buildSlider(
                    'Initial Creatures',
                    config.initialCreatures.toDouble(),
                    5,
                    50,
                    (v) => setState(() {
                      config = config.copyWith(initialCreatures: v.round());
                    }),
                  ),
                ]),
                _buildSection('Food', [
                  _buildSlider(
                    'Initial Spawn Chance',
                    config.initialSpawnChance,
                    0.01,
                    0.5,
                    (v) => setState(() {
                      config = config.copyWith(initialSpawnChance: v);
                    }),
                  ),
                  _buildSlider(
                    'Min Food Count',
                    config.minFoodCount.toDouble(),
                    1,
                    20,
                    (v) => setState(() {
                      config = config.copyWith(minFoodCount: v.round());
                    }),
                  ),
                  _buildSlider(
                    'Food Energy Value',
                    config.foodEnergyValue,
                    5,
                    50,
                    (v) => setState(() {
                      config = config.copyWith(foodEnergyValue: v);
                    }),
                  ),
                ]),
                _buildSection('Genetics', [
                  _buildSlider(
                    'Mutation Rate',
                    config.mutationRate,
                    0.01,
                    0.5,
                    (v) => setState(() {
                      config = config.copyWith(mutationRate: v);
                    }),
                  ),
                  _buildSlider(
                    'Initial Size',
                    config.initialMaxSize,
                    0.5,
                    3.0,
                    (v) => setState(() {
                      config = config.copyWith(initialMaxSize: v);
                    }),
                  ),
                  _buildSlider(
                    'Initial Speed',
                    config.initialMaxSpeed,
                    1.0,
                    5.0,
                    (v) => setState(() {
                      config = config.copyWith(initialMaxSpeed: v);
                    }),
                  ),
                  _buildSlider(
                    'Initial Sense',
                    config.initialMaxSense,
                    20,
                    150,
                    (v) => setState(() {
                      config = config.copyWith(initialMaxSense: v);
                    }),
                  ),
                ]),
                _buildSection('Creature', [
                  _buildSlider(
                    'Reproduction Threshold',
                    config.reproductionThreshold,
                    0.5,
                    1.0,
                    (v) => setState(() {
                      config = config.copyWith(reproductionThreshold: v);
                    }),
                  ),
                  _buildSlider(
                    'Energy Cost Multiplier',
                    config.energyCostMultiplier,
                    0.0001,
                    0.002,
                    (v) => setState(() {
                      config = config.copyWith(energyCostMultiplier: v);
                    }),
                  ),
                  _buildSlider(
                    'Max Age',
                    config.maxAge.toDouble(),
                    600,
                    4800,
                    (v) => setState(() {
                      config = config.copyWith(maxAge: v.round());
                    }),
                  ),
                ]),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.restore, size: 22),
                    label: const Text(
                      'Reset to Defaults',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: Colors.blueAccent,
            inactiveColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(config.toJson());
      await prefs.setString('simulation_config', configJson);

      widget.onConfigSaved(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetToDefaults() {
    setState(() {
      config = SimulationConfig();
    });
  }
}
