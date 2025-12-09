import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/simulation_stats.dart';
import '../utils/csv_export.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  SimulationStats? stats;
  bool isLoading = true;
  List<String> history = [];
  String? currentTimestamp;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats({String? timestamp}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load history
      final savedSimulations = prefs.getStringList('saved_simulations') ?? [];
      // Sort desc (newest first)
      history = savedSimulations.reversed.toList();

      String? timestampToLoad = timestamp;

      // If we have a specific timestamp to load, use it.
      // Otherwise use the latest global one.
      if (timestampToLoad == null && history.isNotEmpty) {
        timestampToLoad = history.first;
      }

      if (timestampToLoad != null) {
        await _loadStatsFor(timestampToLoad);
      } else {
        setState(() {
          stats = SimulationStats();
          isLoading = false;
        });
      }
    } catch (e) {
      // Error loading
      if (mounted) {
        setState(() {
          stats = SimulationStats();
          isLoading = false;
        });
      }
    }
  }

  List<StatPoint> _parseStatsJson(String jsonStr) {
    final points = <StatPoint>[];
    try {
      final List<dynamic> data = jsonDecode(jsonStr);
      for (final item in data) {
        points.add(
          StatPoint(
            time: item['time'] as int? ?? 0,
            population: item['population'] as int? ?? 0,
            foodCount: item['foodCount'] as int? ?? 0,
            avgSpeed: (item['avgSpeed'] as num?)?.toDouble() ?? 0.0,
            avgSize: (item['avgSize'] as num?)?.toDouble() ?? 0.0,
            avgSense: (item['avgSense'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    } catch (e) {
      // Parse error - return empty list
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayStats = stats ?? SimulationStats();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportCSV,
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
            tooltip: 'History',
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
          child: displayStats.points.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(displayStats),
                      const SizedBox(height: 20),
                      _buildChartSection(displayStats),
                      const SizedBox(height: 20),
                      _buildTraitEvolutionSection(displayStats),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No statistics yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Run a simulation to see statistics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(SimulationStats stats) {
    if (stats.points.isEmpty) return const SizedBox.shrink();

    final latest = stats.points.last;
    final first = stats.points.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Duration',
                    '${latest.time}s',
                    Icons.timer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Final Population',
                    '${latest.population}',
                    Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Population Change',
                    '${latest.population - first.population}',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildChartSection(SimulationStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Population & Food Over Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 250,
                  width: constraints.maxWidth,
                  child: CustomPaint(
                    painter: _PopulationChartPainter(stats.points),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Evolution of Traits (Speed & Size)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 250,
                  width: constraints.maxWidth,
                  child: CustomPaint(
                    painter: _SpeedSizeChartPainter(stats.points),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'Evolution of Traits (Sense)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 250,
                  width: constraints.maxWidth,
                  child: CustomPaint(painter: _SenseChartPainter(stats.points)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitEvolutionSection(SimulationStats stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trait Evolution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTraitCard(
              'Speed',
              stats.points.map((p) => p.avgSpeed).toList(),
              Colors.blue,
            ),
            const SizedBox(height: 14),
            _buildTraitCard(
              'Size',
              stats.points.map((p) => p.avgSize).toList(),
              Colors.green,
            ),
            const SizedBox(height: 14),
            _buildTraitCard(
              'Sense',
              stats.points.map((p) => p.avgSense).toList(),
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitCard(String name, List<double> values, Color color) {
    if (values.isEmpty) return const SizedBox.shrink();

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final latest = values.last;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                latest.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min: ${min.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Max: ${max.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Simulation History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No saved simulations',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final timestamp = history[index];
                      final isSelected = timestamp == currentTimestamp;
                      final date =
                          DateTime.tryParse(timestamp) ?? DateTime.now();
                      final formattedDate =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                      return ListTile(
                        leading: Icon(
                          Icons.insights,
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.white54,
                        ),
                        title: Text(
                          formattedDate,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.blueAccent)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _loadStatsFor(timestamp);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportCSV() async {
    if (stats == null || stats!.points.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No statistics to export'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await CSVExport.shareCSV(stats!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV statistics exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStatsFor(String timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsKey = 'latest_stats_$timestamp';
      final statsJson = prefs.getString(statsKey);

      if (statsJson != null) {
        final loadedStats = SimulationStats();
        final points = _parseStatsJson(statsJson);
        loadedStats.points.addAll(points);

        setState(() {
          stats = loadedStats;
          currentTimestamp = timestamp;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }
}

class _PopulationChartPainter extends CustomPainter {
  final List<StatPoint> points;

  _PopulationChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final padding = 50.0;
    final chartWidth = (size.width - padding * 2).clamp(0.0, double.infinity);
    final chartHeight = (size.height - padding * 2).clamp(0.0, double.infinity);

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxTime = points.last.time.toDouble();
    if (maxTime <= 0) return;

    final maxPop = points
        .map((p) => p.population)
        .reduce((a, b) => a > b ? a : b);
    final maxFood = points
        .map((p) => p.foodCount)
        .reduce((a, b) => a > b ? a : b);
    final maxValue = (maxPop > maxFood ? maxPop : maxFood).clamp(
      1.0,
      double.infinity,
    );

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    for (int i = 0; i <= 5; i++) {
      final x = padding + (chartWidth / 5) * i;
      canvas.drawLine(
        Offset(x, padding),
        Offset(x, size.height - padding),
        gridPaint,
      );
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw labels
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 10,
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = (maxValue / 5) * (5 - i);
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      final yPos = (padding + (chartHeight / 5) * i - 6).clamp(
        0.0,
        size.height,
      );
      textPainter.paint(canvas, Offset(5, yPos));
    }

    // X-axis labels (Time)
    for (int i = 0; i <= 5; i++) {
      final value = (maxTime / 5) * i;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      final xPos = (padding + (chartWidth / 5) * i - textPainter.width / 2)
          .clamp(0.0, size.width);
      textPainter.paint(canvas, Offset(xPos, size.height - padding + 5));
    }

    // X-axis label
    textPainter.text = TextSpan(text: 'Time (s)', style: textStyle);
    textPainter.layout();
    final xLabelX = (size.width / 2 - textPainter.width / 2).clamp(
      0.0,
      size.width - textPainter.width,
    );
    final xLabelY = (size.height - padding + 5).clamp(0.0, size.height);
    textPainter.paint(canvas, Offset(xLabelX, xLabelY));

    // Draw population line
    final popPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final popPath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = (padding + (point.time / maxTime) * chartWidth).clamp(
        padding,
        size.width - padding,
      );
      final y =
          (size.height - padding - (point.population / maxValue) * chartHeight)
              .clamp(padding, size.height - padding);

      if (i == 0) {
        popPath.moveTo(x, y);
      } else {
        popPath.lineTo(x, y);
      }
    }
    canvas.drawPath(popPath, popPaint);

    // Draw food line
    final foodPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final foodPath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = (padding + (point.time / maxTime) * chartWidth).clamp(
        padding,
        size.width - padding,
      );
      final y =
          (size.height - padding - (point.foodCount / maxValue) * chartHeight)
              .clamp(padding, size.height - padding);

      if (i == 0) {
        foodPath.moveTo(x, y);
      } else {
        foodPath.lineTo(x, y);
      }
    }
    canvas.drawPath(foodPath, foodPaint);

    // Draw legend
    _drawLegend(canvas, size, [
      ('Population', Colors.cyan),
      ('Food', Colors.green),
    ]);
  }

  void _drawLegend(Canvas canvas, Size size, List<(String, Color)> items) {
    final legendWidth = 100.0;
    final startX = (size.width - legendWidth - 10).clamp(
      10.0,
      size.width - legendWidth,
    );
    final startY = 20.0;
    final itemHeight = 20.0;

    for (int i = 0; i < items.length; i++) {
      final (label, color) = items[i];
      final y = (startY + i * itemHeight).clamp(0.0, size.height - itemHeight);

      // Draw line sample
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final lineY = (y + 8).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(startX + 20, lineY),
        linePaint,
      );

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final labelX = (startX + 25).clamp(0.0, size.width - textPainter.width);
      final labelY = y.clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(_PopulationChartPainter oldDelegate) => false;
}

class _SpeedSizeChartPainter extends CustomPainter {
  final List<StatPoint> points;

  _SpeedSizeChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final padding = 50.0;
    final chartWidth = (size.width - padding * 2).clamp(0.0, double.infinity);
    final chartHeight = (size.height - padding * 2).clamp(0.0, double.infinity);

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxTime = points.last.time.toDouble();
    if (maxTime <= 0) return;

    final maxSpeed = points
        .map((p) => p.avgSpeed)
        .reduce((a, b) => a > b ? a : b);
    final maxSize = points
        .map((p) => p.avgSize)
        .reduce((a, b) => a > b ? a : b);
    final maxValue = (maxSpeed > maxSize ? maxSpeed : maxSize).clamp(
      0.001,
      double.infinity,
    );

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw labels
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 10,
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = (maxValue / 5) * (5 - i);
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(1),
        style: textStyle,
      );
      textPainter.layout();
      final yPos = (padding + (chartHeight / 5) * i - 6).clamp(
        0.0,
        size.height,
      );
      textPainter.paint(canvas, Offset(5, yPos));
    }

    // X-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = (maxTime / 5) * i;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      final xPos = (padding + (chartWidth / 5) * i - textPainter.width / 2)
          .clamp(0.0, size.width);
      textPainter.paint(canvas, Offset(xPos, size.height - padding + 5));
    }

    // Draw speed line
    final speedPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final speedPath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = (padding + (point.time / maxTime) * chartWidth).clamp(
        padding,
        size.width - padding,
      );
      final y =
          (size.height - padding - (point.avgSpeed / maxValue) * chartHeight)
              .clamp(padding, size.height - padding);

      if (i == 0) {
        speedPath.moveTo(x, y);
      } else {
        speedPath.lineTo(x, y);
      }
    }
    canvas.drawPath(speedPath, speedPaint);

    // Draw size line
    final sizePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final sizePath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = (padding + (point.time / maxTime) * chartWidth).clamp(
        padding,
        size.width - padding,
      );
      final y =
          (size.height - padding - (point.avgSize / maxValue) * chartHeight)
              .clamp(padding, size.height - padding);

      if (i == 0) {
        sizePath.moveTo(x, y);
      } else {
        sizePath.lineTo(x, y);
      }
    }
    canvas.drawPath(sizePath, sizePaint);

    // Draw legend
    _drawLegend(canvas, size, [
      ('Avg Speed', Colors.red),
      ('Avg Size', Colors.blue),
    ]);
  }

  void _drawLegend(Canvas canvas, Size size, List<(String, Color)> items) {
    final legendWidth = 100.0;
    final startX = (size.width - legendWidth - 10).clamp(
      10.0,
      size.width - legendWidth,
    );
    final startY = 20.0;
    final itemHeight = 20.0;

    for (int i = 0; i < items.length; i++) {
      final (label, color) = items[i];
      final y = (startY + i * itemHeight).clamp(0.0, size.height - itemHeight);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final lineY = (y + 8).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(startX + 20, lineY),
        linePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final labelX = (startX + 25).clamp(0.0, size.width - textPainter.width);
      final labelY = y.clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(_SpeedSizeChartPainter oldDelegate) => false;
}

class _SenseChartPainter extends CustomPainter {
  final List<StatPoint> points;

  _SenseChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    final padding = 50.0;
    final chartWidth = (size.width - padding * 2).clamp(0.0, double.infinity);
    final chartHeight = (size.height - padding * 2).clamp(0.0, double.infinity);

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxTime = points.last.time.toDouble();
    if (maxTime <= 0) return;

    final maxSense = points
        .map((p) => p.avgSense)
        .reduce((a, b) => a > b ? a : b);
    if (maxSense <= 0) return;

    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = padding + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );

    // Draw labels
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 10,
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = (maxSense / 5) * (5 - i);
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(1),
        style: textStyle,
      );
      textPainter.layout();
      final yPos = (padding + (chartHeight / 5) * i - 6).clamp(
        0.0,
        size.height,
      );
      textPainter.paint(canvas, Offset(5, yPos));
    }

    // X-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = (maxTime / 5) * i;
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: textStyle,
      );
      textPainter.layout();
      final xPos = (padding + (chartWidth / 5) * i - textPainter.width / 2)
          .clamp(0.0, size.width);
      textPainter.paint(canvas, Offset(xPos, size.height - padding + 5));
    }

    // Draw sense line
    final sensePaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final sensePath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final x = (padding + (point.time / maxTime) * chartWidth).clamp(
        padding,
        size.width - padding,
      );
      final y =
          (size.height - padding - (point.avgSense / maxSense) * chartHeight)
              .clamp(padding, size.height - padding);

      if (i == 0) {
        sensePath.moveTo(x, y);
      } else {
        sensePath.lineTo(x, y);
      }
    }
    canvas.drawPath(sensePath, sensePaint);

    // Draw legend
    _drawLegend(canvas, size, [('Avg Sense', Colors.purple)]);
  }

  void _drawLegend(Canvas canvas, Size size, List<(String, Color)> items) {
    final legendWidth = 100.0;
    final startX = (size.width - legendWidth - 10).clamp(
      10.0,
      size.width - legendWidth,
    );
    final startY = 20.0;
    final itemHeight = 20.0;

    for (int i = 0; i < items.length; i++) {
      final (label, color) = items[i];
      final y = (startY + i * itemHeight).clamp(0.0, size.height - itemHeight);

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final lineY = (y + 8).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(startX + 20, lineY),
        linePaint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final labelX = (startX + 25).clamp(0.0, size.width - textPainter.width);
      final labelY = y.clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(_SenseChartPainter oldDelegate) => false;
}
