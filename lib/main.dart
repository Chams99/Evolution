import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/lab_screen.dart';
import 'app/sprites.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Sprites.load();
  runApp(const EvolutionApp());
}

/// Light status and navigation bar icons over the dark lab, on every platform.
const _systemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarColor: Palette.ink,
  systemNavigationBarIconBrightness: Brightness.light,
);

class EvolutionApp extends StatelessWidget {
  const EvolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evolution',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => AnnotatedRegion(value: _systemBars, child: child!),
      home: const LabScreen(),
    );
  }
}
