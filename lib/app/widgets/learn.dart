import 'package:flutter/material.dart';

import '../lab_controller.dart';
import '../lessons.dart';
import '../theme.dart';

/// The active lesson: its question and live goal, then the explanation.
class LessonStrip extends StatelessWidget {
  const LessonStrip({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final run = controller.lesson;
    if (run == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: controller.samples,
      builder: (context, _, _) {
        final lesson = run.lesson;
        final number = lessons.indexOf(lesson) + 1;
        final done = run.completed;
        final accent = Palette.gold;
        final next = controller.nextLesson;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: done ? 0.7 : 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    done ? 'LESSON $number COMPLETE' : 'LESSON $number OF ${lessons.length}',
                    style: Styles.label.copyWith(color: accent),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: controller.leaveLesson,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text('LEAVE', style: Styles.label.copyWith(color: Palette.faint)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(lesson.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(done ? lesson.explanation : lesson.question, style: Theme.of(context).textTheme.bodyMedium),
              if (!done) ...[
                const SizedBox(height: 6),
                Text(lesson.watch, style: Theme.of(context).textTheme.bodySmall),
                if (controller.speed > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Running at ${controller.speed}× so generations pass quickly. Slow it down any time.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Palette.faint),
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: run.progress.value.clamp(0, 1).toDouble(),
                    minHeight: 5,
                    color: accent,
                    backgroundColor: Palette.raised,
                  ),
                ),
                const SizedBox(height: 6),
                Text(run.progress.label, style: Styles.readout.copyWith(fontSize: 11.5, color: Palette.muted)),
              ] else ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (next != null)
                      FilledButton(
                        onPressed: () => controller.startLesson(next),
                        style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.surface),
                        child: Text('Next: ${next.title}'),
                      ),
                    OutlinedButton(
                      onPressed: controller.leaveLesson,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.cream,
                        side: const BorderSide(color: Palette.lineStrong),
                      ),
                      child: const Text('Keep exploring this world'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Every lesson, with its status.
class LessonList extends StatelessWidget {
  const LessonList({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final done = controller.completedLessons;
    final active = controller.lesson?.lesson;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Five short experiments. Each one sets up a world, asks a question, and explains the answer once you '
          'have watched it happen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          '${done.length} of ${lessons.length} complete',
          style: Styles.label.copyWith(color: done.length == lessons.length ? Palette.gold : Palette.faint),
        ),
        const SizedBox(height: 14),
        for (final (i, lesson) in lessons.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LessonCard(
              number: i + 1,
              lesson: lesson,
              done: done.contains(lesson.id),
              active: identical(lesson, active),
              onStart: () => controller.startLesson(lesson),
            ),
          ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.number,
    required this.lesson,
    required this.done,
    required this.active,
    required this.onStart,
  });

  final int number;
  final Lesson lesson;
  final bool done;
  final bool active;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final border = active ? Palette.gold : (done ? Palette.gold.withValues(alpha: 0.4) : Palette.line);
    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onStart,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Palette.gold : Colors.transparent,
                  border: Border.all(color: done ? Palette.gold : Palette.lineStrong),
                ),
                child: done
                    ? const Icon(Icons.check, size: 15, color: Palette.surface)
                    : Text('$number', style: Styles.readout.copyWith(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(lesson.question, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Text(
                      active ? 'IN PROGRESS' : (done ? 'REPLAY' : 'START'),
                      style: Styles.label.copyWith(color: active ? Palette.gold : Palette.cream),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
