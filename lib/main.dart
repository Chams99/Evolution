import 'package:flutter/material.dart';

import 'app/lab_screen.dart';
import 'app/theme.dart';

void main() => runApp(const EvolutionApp());

class EvolutionApp extends StatelessWidget {
  const EvolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evolution',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LabScreen(),
    );
  }
}
