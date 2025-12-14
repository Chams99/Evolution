import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/simulation_page.dart';
import 'pages/statistics_page.dart';
import 'pages/settings_page.dart';
import 'models/simulation_config.dart';

void main() {
  runApp(const EvolutionGameApp());
}

class EvolutionGameApp extends StatelessWidget {
  const EvolutionGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evolution Game',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/simulation': (context) {
          final duration = ModalRoute.of(context)!.settings.arguments as int?;
          return SimulationPage(timerDurationSeconds: duration);
        },
        '/statistics': (context) => const StatisticsPage(),
        '/settings': (context) => SettingsPage(
          initialConfig: SimulationConfig(),
          onConfigSaved: (config) {
            // Config saved callback
          },
        ),
      },
    );
  }
}
