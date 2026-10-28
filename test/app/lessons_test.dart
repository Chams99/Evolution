import 'package:evolution/app/lab_controller.dart';
import 'package:evolution/app/lessons.dart';
import 'package:evolution/app/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays a lesson headless, one simulated second at a time, as the app would.
Future<LabController> play(Lesson lesson, {required int seconds, ProgressStore? store}) async {
  final controller = LabController(store: store)..startLesson(lesson);
  for (var i = 0; i < seconds && !(controller.lesson?.completed ?? true); i++) {
    controller.stepSecond();
  }
  return controller;
}

void main() {
  // Each automatic lesson must be reachable with its fixed seed in a sensible time.
  for (final entry in {'fastest': 600, 'seasons': 130, 'arms-race': 600, 'variation': 130}.entries) {
    test('lesson "${entry.key}" can be completed within ${entry.value} simulated seconds', () async {
      final lesson = lessons.firstWhere((l) => l.id == entry.key);
      final store = MemoryProgressStore(seen: true);
      final controller = await play(lesson, seconds: entry.value, store: store);
      expect(controller.lesson!.completed, isTrue, reason: controller.lesson!.progress.label);
      expect(store.completed, contains(lesson.id));
      controller.dispose();
    });
  }

  test('without variation the traits do not move', () async {
    final controller = await play(lessons.firstWhere((l) => l.id == 'variation'), seconds: 130);
    final history = controller.world.history;
    for (final trait in history.first.traits.keys) {
      expect(history.last.traits[trait]!.mean, closeTo(history.first.traits[trait]!.mean, 1e-9));
      expect(history.last.traits[trait]!.deviation, lessThan(1e-6));
    }
    controller.dispose();
  });

  test('the bottleneck lesson needs a meteor strike, then a recovery', () async {
    final lesson = lessons.firstWhere((l) => l.id == 'bottleneck');
    final controller = LabController()..startLesson(lesson);
    expect(controller.tool, Tool.meteor);
    for (var i = 0; i < 60; i++) {
      controller.stepSecond();
    }
    expect(controller.lesson!.progress.value, lessThan(0.5));

    final world = controller.world;
    for (var x = 60.0; x < world.config.width; x += 120) {
      for (var y = 60.0; y < world.config.height; y += 120) {
        if (world.organisms.length > controller.lesson!.memory['peak']! * 0.3) controller.tapField(x, y);
      }
    }
    controller.stepSecond();
    expect(controller.lesson!.progress.value, greaterThanOrEqualTo(0.5));

    for (var i = 0; i < 900 && !controller.lesson!.completed; i++) {
      controller.stepSecond();
    }
    expect(controller.lesson!.completed, isTrue, reason: controller.lesson!.progress.label);
    controller.dispose();
  });

  test('completed lessons are remembered', () async {
    final store = MemoryProgressStore(completed: {'seasons'}, seen: true);
    final controller = LabController(store: store);
    await Future<void>.delayed(Duration.zero);
    expect(controller.completedLessons, contains('seasons'));
    controller.dispose();
  });
}
