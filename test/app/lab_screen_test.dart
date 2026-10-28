import 'package:evolution/app/lab_controller.dart';
import 'package:evolution/app/lab_screen.dart';
import 'package:evolution/app/theme.dart';
import 'package:evolution/app/widgets/field_view.dart';
import 'package:evolution/sim/world_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LabController> pumpLab(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = LabController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: LabScreen(controller: controller),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  return controller;
}

/// The simulation never settles, so pump a fixed number of frames instead.
Future<void> frames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder sidePanel() => find.byType(Scrollable).last;

void main() {
  testWidgets('desktop layout shows the field and the side panel', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    expect(find.byType(FieldView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('POPULATION'), findsWidgets);
    await tester.scrollUntilVisible(find.text('PRESETS'), 300, scrollable: sidePanel());
    expect(find.text('PRESETS'), findsOneWidget);
    expect(controller.world.tick, greaterThan(0));
  });

  for (final size in const [Size(360, 740), Size(390, 844), Size(820, 1180)]) {
    testWidgets('narrow layout at ${size.width.toInt()}×${size.height.toInt()} uses tabs without overflow', (
      tester,
    ) async {
      await pumpLab(tester, size);
      expect(find.byType(TabBar), findsOneWidget);
      await tester.tap(find.text('SETUP'));
      await frames(tester);
      expect(find.text('PRESETS'), findsOneWidget);
      await tester.tap(find.text('ORGANISM'));
      await frames(tester);
      expect(find.textContaining('Tap an organism'), findsOneWidget);
    });
  }

  testWidgets('play and pause stop the clock', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Pause'));
    await tester.pump();
    final paused = controller.world.tick;
    await frames(tester);
    expect(controller.world.tick, paused);
    await tester.tap(find.text('+1 s'));
    await tester.pump();
    expect(controller.world.tick, paused + controller.config.ticksPerSecond);
    await tester.tap(find.text('Play'));
    await frames(tester, 5);
    expect(controller.world.tick, greaterThan(paused + controller.config.ticksPerSecond));
  });

  testWidgets('choosing a preset restarts the run', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.scrollUntilVisible(find.text('Drought'), 300, scrollable: sidePanel());
    await tester.drag(sidePanel(), const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.text('Drought'));
    await frames(tester, 2);
    expect(controller.preset, Preset.drought);
    expect(find.text('DROUGHT · SEED 1'), findsOneWidget);
  });

  testWidgets('tapping empty ground drops food, tapping an organism selects it', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Pause'));
    await tester.pump();

    final field = tester.getRect(find.byType(FieldView));
    final scale = field.width / controller.config.width;
    controller.world.organisms.removeWhere((o) => o.x < 60 && o.y < 60);
    final before = controller.world.food.length;
    await tester.tapAt(field.topLeft + const Offset(20, 20) * scale);
    await tester.pump();
    expect(controller.world.food.length, greaterThan(before));

    final target = controller.world.organisms.first;
    await tester.tapAt(field.topLeft + Offset(target.x, target.y) * scale);
    await tester.pump();
    expect(controller.selected, same(target));
    expect(find.text('ORGANISM #${target.id}'), findsOneWidget);
  });

  test('links can open a specific run', () {
    final controller = LabController.fromQuery({'preset': 'hunters', 'seed': '7', 'at': '30', 'speed': '4'});
    addTearDown(controller.dispose);
    expect(controller.preset, Preset.hunters);
    expect(controller.config.seed, 7);
    expect(controller.world.seconds, 30);
    expect(controller.speed, 4);
  });
}
