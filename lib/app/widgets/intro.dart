import 'package:flutter/material.dart';

import '../../sim/genome.dart';
import '../lab_controller.dart';
import '../lessons.dart';
import '../theme.dart';

/// Three short pages shown on the first visit, and from the help button.
class IntroOverlay extends StatefulWidget {
  const IntroOverlay({super.key, required this.controller});

  final LabController controller;

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> {
  int _page = 0;

  static const _pages = 3;

  void _finish({bool startLesson = false}) {
    widget.controller.dismissIntro();
    if (startLesson) widget.controller.startLesson(lessons.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final last = _page == _pages - 1;
    return Material(
      color: Palette.ink.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Palette.lineStrong),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_page + 1} / $_pages', style: Styles.label.copyWith(color: Palette.terracotta)),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: KeyedSubtree(key: ValueKey(_page), child: _content(theme)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(foregroundColor: Palette.muted),
                          child: Text(last ? 'Explore freely' : 'Skip'),
                        ),
                        const Spacer(),
                        if (_page > 0)
                          TextButton(
                            onPressed: () => setState(() => _page--),
                            style: TextButton.styleFrom(foregroundColor: Palette.cream),
                            child: const Text('Back'),
                          ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: last ? () => _finish(startLesson: true) : () => setState(() => _page++),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.gold,
                            foregroundColor: Palette.surface,
                          ),
                          child: Text(last ? 'Start the first lesson' : 'Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(TextTheme theme) {
    switch (_page) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A drop of pond water', style: theme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'You are looking down a microscope at a living drop. Each coloured cell is a microbe. It hunts '
              'algae, swells as it eats, and divides in two. Its daughters inherit three traits, each with a '
              'tiny random change. Every trait helps, and every trait costs energy.',
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _TraitLine(
              Trait.size,
              'Size',
              'A bigger cell digests whole algae and, with predators on, engulfs others.',
            ),
            const _TraitLine(
              Trait.speed,
              'Speed',
              'A longer, faster tail reaches algae first, but swimming burns energy.',
            ),
            const _TraitLine(Trait.sense, 'Sense', 'A bigger red eyespot spots algae and danger from further away.'),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You run the lab', style: theme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Nothing is scripted. You set the conditions, and the microbes adapt or die out.',
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _ToolLine(Icons.colorize_outlined, 'Tap a microbe', 'to see its species and follow its family.'),
            const _ToolLine(Icons.grain, 'Tap empty water', 'to pipette in algae, or add a whole culture.'),
            const _ToolLine(Icons.flare, 'UV pulse and drain', 'cause disasters, then watch who recovers.'),
            const _ToolLine(Icons.fast_forward, 'Speed up to 16×', 'to watch hundreds of generations go by.'),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learn by experiment', style: theme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'The Learn tab has ${lessons.length} short experiments, from why microbes get faster to what a '
              'disaster does to a population. Each one tells you what to watch and explains what happened once you '
              'have seen it.',
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Under the drop, the trait cards show which traits are being favoured right now, based on which '
              'microbes are actually dividing. Every microbe also gets a Latin name from its traits.',
              style: theme.bodySmall,
            ),
          ],
        );
    }
  }
}

class _TraitLine extends StatelessWidget {
  const _TraitLine(this.trait, this.name, this.text);

  final Trait trait;
  final String name;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: Palette.trait(trait), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$name  ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(color: Palette.muted),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolLine extends StatelessWidget {
  const _ToolLine(this.icon, this.lead, this.text);

  final IconData icon;
  final String lead;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Palette.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$lead ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: text,
                    style: const TextStyle(color: Palette.muted),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
