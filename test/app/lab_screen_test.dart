import 'package:evolution/app/lab_controller.dart';
import 'package:evolution/app/lab_screen.dart';
import 'package:evolution/app/lessons.dart';
import 'package:evolution/app/progress_store.dart';
import 'package:evolution/app/theme.dart';
import 'package:evolution/app/widgets/field_view.dart';
import 'package:evolution/sim/world_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LabController> pumpLab(WidgetTester tester, Size size, {ProgressStore? store}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = LabController(store: store);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: LabScreen(controller: controller),
    ),
  );
  await frames(tester, 5);
  return controller;
}

/// The simulation never settles, so pump a fixed number of frames instead.
Future<void> frames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openTab(WidgetTester tester, String name) async {
  await tester.tap(find.widgetWithText(Tab, name));
  await frames(tester);
}

Offset fieldPoint(WidgetTester tester, LabController controller, double x, double y) {
  final field = tester.getRect(find.byType(FieldView));
  return field.topLeft + Offset(x, y) * (field.width / controller.config.width);
}

void main() {
  testWidgets('desktop layout shows the field with learn, charts and setup tabs', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    expect(find.byType(FieldView), findsOneWidget);
    expect(find.text('Survival of the fastest'), findsOneWidget);
    await openTab(tester, 'CHARTS');
    expect(find.text('RIGHT NOW'), findsOneWidget);
    await openTab(tester, 'SETUP');
    expect(find.text('PRESETS'), findsOneWidget);
    expect(controller.world.tick, greaterThan(0));
  });

  for (final size in const [Size(360, 740), Size(390, 844), Size(820, 1180)]) {
    testWidgets('narrow layout at ${size.width.toInt()}×${size.height.toInt()} has every tab without overflow', (
      tester,
    ) async {
      await pumpLab(tester, size);
      expect(find.text('RIGHT NOW'), findsOneWidget);
      await openTab(tester, 'LEARN');
      expect(find.text('Survival of the fastest'), findsOneWidget);
      await openTab(tester, 'ORGANISM');
      expect(find.textContaining('Tap an organism'), findsOneWidget);
      await openTab(tester, 'SETUP');
      expect(find.text('PRESETS'), findsOneWidget);
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
    await openTab(tester, 'SETUP');
    await tester.tap(find.text('Drought'));
    await frames(tester, 2);
    expect(controller.preset, Preset.drought);
    expect(find.text('DROUGHT · SEED 1'), findsOneWidget);
  });

  testWidgets('the hand tool drops food on empty ground and selects organisms', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Pause'));
    await tester.pump();

    controller.world.organisms.removeWhere((o) => o.x > 400 && o.x < 520 && o.y > 240 && o.y < 360);
    final before = controller.world.food.length;
    await tester.tapAt(fieldPoint(tester, controller, 460, 300));
    await tester.pump();
    expect(controller.world.food.length, greaterThan(before));

    final target = controller.world.organisms.firstWhere((o) => o.x > 200 && o.y > 120 && o.y < 480);
    await tester.tapAt(fieldPoint(tester, controller, target.x, target.y));
    await tester.pump();
    expect(controller.selected, same(target));
    expect(find.text('ORGANISM #${target.id}'), findsOneWidget);
  });

  testWidgets('the meteor tool strikes where you tap', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Meteor'));
    await tester.pump();
    expect(controller.tool, Tool.meteor);
    final target = controller.world.organisms.firstWhere((o) => o.x > 200 && o.y > 120 && o.y < 480);
    await tester.tapAt(fieldPoint(tester, controller, target.x, target.y));
    await tester.pump();
    expect(target.alive, isFalse);
    expect(controller.world.totalStruck, greaterThan(0));
    expect(find.textContaining('Meteor strike'), findsOneWidget);
  });

  testWidgets('famine and food rain change the food on the ground', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Food rain'));
    await tester.pump();
    final rained = controller.world.food.length;
    await tester.tap(find.text('Famine'));
    await tester.pump();
    expect(controller.world.food.length, lessThan(rained));
  });

  testWidgets('starting a lesson shows its question and goal', (tester) async {
    final controller = await pumpLab(tester, const Size(1440, 900));
    await tester.tap(find.text('Survival of the fastest'));
    await frames(tester, 3);
    expect(controller.lesson?.lesson.id, 'fastest');
    expect(find.text('LESSON 1 OF ${lessons.length}'), findsOneWidget);
    expect(find.textContaining('of the +30% goal'), findsOneWidget);
    await tester.tap(find.text('LEAVE'));
    await tester.pump();
    expect(controller.lesson, isNull);
  });

  testWidgets('the intro shows on a first visit and can start the first lesson', (tester) async {
    final store = MemoryProgressStore();
    final controller = await pumpLab(tester, const Size(1440, 900), store: store);
    expect(find.text('Meet the organisms'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await frames(tester, 3);
    await tester.tap(find.text('Next'));
    await frames(tester, 3);
    await tester.tap(find.text('Start the first lesson'));
    await frames(tester, 3);
    expect(store.seen, isTrue);
    expect(find.text('Meet the organisms'), findsNothing);
    expect(controller.lesson?.lesson, lessons.first);
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
