import 'package:flutter/material.dart';
import '../models/simulation.dart' as sim;

class StatsPanel extends StatelessWidget {
  final sim.Simulation simulation;

  const StatsPanel({super.key, required this.simulation});

  @override
  Widget build(BuildContext context) {
    final time = simulation.frameCount ~/ simulation.config.fps;
    final population = simulation.creatures.length;
    final foodCount = simulation.foods.length;
    final scarcityPercent = (simulation.scarcity * 100).toStringAsFixed(1);

    double avgSpeed = 0;
    double avgSize = 0;
    double avgSense = 0;

    if (population > 0) {
      avgSpeed =
          simulation.creatures.map((c) => c.dna.speed).reduce((a, b) => a + b) /
          population;
      avgSize =
          simulation.creatures.map((c) => c.dna.size).reduce((a, b) => a + b) /
          population;
      avgSense =
          simulation.creatures.map((c) => c.dna.sense).reduce((a, b) => a + b) /
          population;
    }

    return Container(
      width: 200,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildStatRow('Time', '${time}s'),
          _buildStatRow('Population', '$population'),
          _buildStatRow('Food', '$foodCount'),
          _buildStatRow('Scarcity', '$scarcityPercent%'),
          const SizedBox(height: 8),
          Text(
            'Average Traits',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildStatRow('Speed', avgSpeed.toStringAsFixed(2)),
          _buildStatRow('Size', avgSize.toStringAsFixed(2)),
          _buildStatRow('Sense', avgSense.toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
