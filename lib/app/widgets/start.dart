import 'package:flutter/material.dart';

import '../experiment_screen.dart';
import '../lab_controller.dart';
import '../lessons.dart';
import '../theme.dart';

/// What to do first: test an idea, follow a lesson, or just watch the drop,
/// which keeps running behind.
class StartOverlay extends StatelessWidget {
  const StartOverlay({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final done = controller.completedLessons;
    final nextLesson = lessons.where((l) => !done.contains(l.id)).firstOrNull ?? lessons.first;
    final options = [
      _Choice(
        icon: Icons.science_outlined,
        title: 'Test an idea',
        detail: 'Change one thing, predict what evolves, and check it against an untouched control drop.',
        primary: true,
        onTap: () {
          controller.dismissStart();
          openExperiment(context, controller);
        },
      ),
      _Choice(
        icon: Icons.school_outlined,
        title: 'Guided experiments',
        detail: done.isEmpty
            ? 'Five short lessons. Each asks a question, sets a goal and explains the answer.'
            : '${done.length} of ${lessons.length} done. Next: ${nextLesson.title}.',
        onTap: () {
          controller.dismissStart();
          controller.startLesson(nextLesson);
        },
      ),
      _Choice(
        icon: Icons.visibility_outlined,
        title: 'Just watch the drop',
        detail: 'Leave it running, tap microbes, and explore at your own pace.',
        onTap: controller.dismissStart,
      ),
    ];
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('LIVE · POND WATER · ×400', style: Styles.label.copyWith(color: Palette.terracotta)),
        const SizedBox(height: 10),
        Text('Evolution', style: theme.titleLarge?.copyWith(fontSize: 44, letterSpacing: -1.6)),
        const SizedBox(height: 10),
        Text(
          'A living drop of pond water. Microbes inherit size, speed and eyesight, and every one of those costs '
          'energy. Nothing is scripted: what spreads is whatever lets a microbe divide before it starves.',
          style: theme.bodyMedium?.copyWith(color: Palette.muted, fontSize: 15),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: () => controller.dismissStart(tour: true),
          icon: const Icon(Icons.help_outline, size: 17),
          label: const Text('New here? Take the one-minute tour'),
          style: TextButton.styleFrom(foregroundColor: Palette.cream, padding: EdgeInsets.zero),
        ),
      ],
    );
    return Material(
      // Darker on phones, where the lab behind would show through between the cards.
      color: Palette.ink.withValues(alpha: MediaQuery.sizeOf(context).width < 720 ? 0.95 : 0.86),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cards = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, o) in options.indexed) ...[if (i > 0) const SizedBox(height: 10), o],
                    ],
                  );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [intro, const SizedBox(height: 22), cards],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: intro),
                      const SizedBox(width: 40),
                      Expanded(flex: 6, child: cards),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? Palette.gold : Palette.cream;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            color: Palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary ? Palette.gold : Palette.lineStrong, width: primary ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle, color: primary ? Palette.gold : Palette.raised),
                child: Icon(icon, size: 21, color: primary ? Palette.surface : Palette.cream),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: accent)),
                    const SizedBox(height: 3),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way back into the experiment screen from the Learn tab.
class ExperimentEntry extends StatelessWidget {
  const ExperimentEntry({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return _Choice(
      icon: Icons.science_outlined,
      title: 'Test your own idea',
      detail: 'Change one thing and compare against a control drop.',
      primary: true,
      onTap: () => openExperiment(context, controller),
    );
  }
}
