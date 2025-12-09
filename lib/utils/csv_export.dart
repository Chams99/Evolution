import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/simulation_stats.dart';

class CSVExport {
  static Future<String> exportToCSV(SimulationStats stats) async {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Time,Population,Food,AvgSpeed,AvgSize,AvgSense');
    
    // CSV Data
    for (final point in stats.points) {
      buffer.writeln(
        '${point.time},'
        '${point.population},'
        '${point.foodCount},'
        '${point.avgSpeed.toStringAsFixed(2)},'
        '${point.avgSize.toStringAsFixed(2)},'
        '${point.avgSense.toStringAsFixed(2)}',
      );
    }
    
    final csvContent = buffer.toString();
    
    // Save to SharedPreferences first
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final key = 'csv_export_$timestamp';
      await prefs.setString(key, csvContent);
      
      // Also save list of export keys
      final exportKeys = prefs.getStringList('csv_export_keys') ?? [];
      exportKeys.add(key);
      await prefs.setStringList('csv_export_keys', exportKeys);
    } catch (e) {
      // Continue even if SharedPreferences fails
    }
    
    // Save to file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final file = File('${directory.path}/evolution_stats_$timestamp.csv');
      await file.writeAsString(csvContent);
      return file.path;
    } catch (e) {
      // If file saving fails, return CSV content as string
      return csvContent;
    }
  }

  static Future<List<String>> getSavedExports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('csv_export_keys') ?? [];
    } catch (e) {
      return [];
    }
  }

  static Future<String?> getExport(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  static Future<void> shareCSV(SimulationStats stats) async {
    try {
      final filePath = await exportToCSV(stats);
      final file = File(filePath);
      
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Evolution Simulation Statistics',
        );
      }
    } catch (e) {
      // Fallback: share as text
      final csvContent = await exportToCSV(stats);
      await Share.share(csvContent, subject: 'Evolution Simulation Statistics');
    }
  }
}
