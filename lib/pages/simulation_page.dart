import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/simulation.dart' as sim;
import '../models/simulation_config.dart';
import '../widgets/creature_painter.dart';
import '../widgets/stats_panel.dart';
import '../utils/csv_export.dart';

class SimulationPage extends StatefulWidget {
  final int? timerDurationSeconds;

  const SimulationPage({super.key, this.timerDurationSeconds});

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  sim.Simulation? simulation;
  Timer? timer;
  Timer? countdownTimer;
  bool showStatsPanel = true;
  int elapsedSeconds = 0;
  int? targetDuration;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    targetDuration = widget.timerDurationSeconds;
    _initializeSimulation();
  }

  Future<void> _initializeSimulation() async {
    // Load saved config from SharedPreferences
    SimulationConfig config = SimulationConfig(); // Default

    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('simulation_config');

      if (configJson != null) {
        final Map<String, dynamic> json = jsonDecode(configJson);
        config = SimulationConfig.fromJson(json);
      }
    } catch (e) {
      // Use default config if loading fails
    }

    // Initialize simulation with loaded config
    simulation = sim.Simulation(config);

    timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ simulation!.config.fps),
      (_) {
        if (mounted && simulation?.isPaused == false) {
          setState(() {
            simulation?.update();
          });
        }
      },
    );

    // Start countdown timer if duration is set
    if (targetDuration != null && targetDuration! > 0) {
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || simulation?.isPaused != false) return;

        setState(() {
          elapsedSeconds++;
          if (elapsedSeconds >= targetDuration!) {
            timer.cancel();
            _handleTimerEnd();
          }
        });
      });
    }

    // Trigger rebuild with initialized simulation
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _handleTimerEnd() async {
    // Pause simulation automatically
    setState(() {
      if (simulation != null) {
        simulation!.isPaused = true;
      }
    });

    if (!mounted) return;

    // Automatically save CSV and graphs to SharedPreferences
    try {
      if (simulation == null) return;

      // Save CSV to SharedPreferences and file
      await CSVExport.exportToCSV(simulation!.stats);

      // Save stats data for Statistics page
      await _saveStatsToPreferences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Timer ended! Simulation paused. Statistics saved and available in Statistics page.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Show dialog
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Simulation Complete'),
              content: const Text(
                'The simulation has completed!\n\nStatistics have been saved and are available in the Statistics page.\n\nWould you like to view them now?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Stay Here'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/statistics');
                  },
                  child: const Text('View Statistics'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timer ended but error saving: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveStatsToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String();

      // Save stats as JSON string
      final statsList = simulation!.stats.points
          .map(
            (point) => {
              'time': point.time,
              'population': point.population,
              'foodCount': point.foodCount,
              'avgSpeed': point.avgSpeed,
              'avgSize': point.avgSize,
              'avgSense': point.avgSense,
            },
          )
          .toList();

      final statsJson = jsonEncode(statsList);
      await prefs.setString('latest_stats_$timestamp', statsJson);

      // Save timestamp for latest stats
      await prefs.setString('latest_stats_timestamp', timestamp);

      // Add to list of saved simulations
      final savedSimulations = prefs.getStringList('saved_simulations') ?? [];
      savedSimulations.add(timestamp);
      await prefs.setStringList('saved_simulations', savedSimulations);
    } catch (e) {
      // Ignore errors
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (simulation == null) return;
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final localPosition = box.globalToLocal(details.globalPosition);
      simulation!.addFood(localPosition.dx, localPosition.dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || simulation == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [const Color(0xFF2A2A72), Colors.black],
              stops: const [0.0, 0.8],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow gradient to show behind app bar
      backgroundColor: Colors.transparent, // Important for gradient

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Evolution Simulation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              showStatsPanel ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                showStatsPanel = !showStatsPanel;
              });
            },
            tooltip: 'Toggle Stats',
          ),
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
          child: GestureDetector(
            onTapDown: _handleTapDown,
            child: Stack(
              children: [
                // Simulation canvas
                CustomPaint(
                  painter: CreaturePainter(
                    creatures: simulation!.creatures,
                    foods: simulation!.foods,
                  ),
                  size: Size.infinite,
                ),

                // Top Section: Stats and (Timer OR Config)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats Panel (Top Left)
                          if (showStatsPanel)
                            Flexible(
                              flex: 0,
                              child: StatsPanel(simulation: simulation!),
                            ),

                          const Spacer(),

                          // Right Side Elements (Timer)
                          if (targetDuration != null && targetDuration! > 0)
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer,
                                          color: Colors.blueAccent,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Time Remaining',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(
                                        targetDuration! - elapsedSeconds,
                                      ),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            (targetDuration! - elapsedSeconds) <
                                                10
                                            ? Colors.red
                                            : Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Section: Instructions and Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Instructions (Above controls, right aligned)
                          _buildInstructionCard(),

                          const SizedBox(height: 8),

                          // Control buttons (Bottom center)
                          Center(child: _buildControlBar()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _buildControlButton(
              icon: simulation?.isPaused == true
                  ? Icons.play_arrow
                  : Icons.pause,
              label: simulation?.isPaused == true ? 'Play' : 'Pause',
              color: Colors.green,
              onPressed: () {
                setState(() {
                  simulation!.isPaused = !simulation!.isPaused;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _buildControlButton(
              icon: Icons.refresh,
              label: 'Reset',
              color: Colors.orange,
              onPressed: () {
                setState(() {
                  simulation!.reset();
                  elapsedSeconds = 0;
                  // Restart countdown timer if duration is set
                  countdownTimer?.cancel();
                  if (targetDuration != null && targetDuration! > 0) {
                    countdownTimer = Timer.periodic(
                      const Duration(seconds: 1),
                      (timer) {
                        if (!mounted || simulation?.isPaused == true) return;

                        setState(() {
                          elapsedSeconds++;
                          if (elapsedSeconds >= targetDuration!) {
                            timer.cancel();
                            _handleTimerEnd();
                          }
                        });
                      },
                    );
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color.withValues(alpha: 0.9) == Colors.black
            ? Colors.white
            : Colors.white, // Keep text white usually
        shadowColor: color.withValues(alpha: 0.4),
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blueAccent),
              const SizedBox(width: 6),
              const Text(
                'Tips',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildInstructionItem('Watch evolution'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
