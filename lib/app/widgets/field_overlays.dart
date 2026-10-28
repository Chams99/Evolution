import 'dart:async';

import 'package:flutter/material.dart';

import '../lab_controller.dart';
import '../theme.dart';

/// The last few milestones, fading out after a few seconds.
class MilestoneFeed extends StatefulWidget {
  const MilestoneFeed({super.key, required this.controller, this.compact = false});

  final LabController controller;

  /// Shows only the latest milestone, for small fields.
  final bool compact;

  static const visibleFor = Duration(seconds: 6);

  @override
  State<MilestoneFeed> createState() => _MilestoneFeedState();
}

class _MilestoneFeedState extends State<MilestoneFeed> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _recent().isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Milestone> _recent() {
    final now = DateTime.now();
    return [
      for (final m in widget.controller.milestones.reversed.take(widget.compact ? 1 : 3))
        if (now.difference(m.shownAt) < MilestoneFeed.visibleFor) m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller.frame,
      builder: (context, _, _) {
        final now = DateTime.now();
        final items = _recent();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final m in items.reversed)
              Opacity(
                opacity: _fade(now.difference(m.shownAt)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _Pill(milestone: m),
                ),
              ),
          ],
        );
      },
    );
  }

  double _fade(Duration age) {
    const fadeStart = Duration(milliseconds: 4500);
    if (age < fadeStart) return 1;
    final t = (age - fadeStart).inMilliseconds / (MilestoneFeed.visibleFor - fadeStart).inMilliseconds;
    return (1 - t).clamp(0, 1).toDouble();
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    final color = switch (milestone.tone) {
      MilestoneTone.good => Palette.cream,
      MilestoneTone.bad => Palette.terracotta,
      MilestoneTone.neutral => Palette.gold,
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Palette.ink.withValues(alpha: 0.82),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(milestone.text, style: const TextStyle(fontSize: 12.5, color: Palette.cream)),
          ),
        ],
      ),
    );
  }
}

/// Camera-style overlay on the live view: recording light, sample label,
/// magnification and a scale bar in micrometres.
class MicroscopeHud extends StatelessWidget {
  const MicroscopeHud({super.key, required this.controller, required this.label});

  final LabController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    const chip = BoxDecoration(color: Palette.hud, borderRadius: BorderRadius.all(Radius.circular(4)));
    final style = Styles.label.copyWith(fontSize: 10, color: Palette.cream);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / controller.config.width;
        final bar = 50 * scale;
        return Stack(
          children: [
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                decoration: chip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RecDot(playing: controller.playing),
                    const SizedBox(width: 6),
                    Text(controller.playing ? 'LIVE' : 'PAUSED', style: style),
                    Text('  ·  $label', style: style.copyWith(color: Palette.muted)),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
                decoration: chip,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('×400', style: style.copyWith(color: Palette.muted)),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: bar, height: 2, color: Palette.cream),
                        const SizedBox(height: 3),
                        Text('50 µm', style: style),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecDot extends StatefulWidget {
  const _RecDot({required this.playing});

  final bool playing;

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.playing ? Tween(begin: 0.35, end: 1.0).animate(_pulse) : const AlwaysStoppedAnimation(1),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.playing ? Palette.terracotta : Palette.faint, shape: BoxShape.circle),
      ),
    );
  }
}

/// The lamp over the slide. Its brightness cycles like seasons and drives how
/// fast algae grow. Shown only when the cycle is on.
class SeasonBadge extends StatelessWidget {
  const SeasonBadge({super.key, required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.config.seasonStrength <= 0) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: controller.samples,
      builder: (context, _, _) {
        final supply = controller.world.foodSupply;
        final (label, color) = supply < 0.75
            ? ('LAMP DIM · ALGAE SCARCE', Palette.terracotta)
            : supply > 1.25
            ? ('LAMP BRIGHT · ALGAE BLOOMING', Palette.food)
            : ('LAMP STEADY', Palette.gold);
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
          decoration: BoxDecoration(color: Palette.hud, borderRadius: BorderRadius.circular(4)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.light_mode_outlined, size: 12, color: color),
                  const SizedBox(width: 5),
                  Text(label, style: Styles.label.copyWith(fontSize: 10, color: color)),
                ],
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 86,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (supply / 2).clamp(0, 1).toDouble(),
                    color: color,
                    backgroundColor: Palette.raised,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tools for poking the world: inspect and feed, meteor, famine, food rain.
class ToolDock extends StatelessWidget {
  const ToolDock({super.key, required this.controller, this.compact = false});

  final LabController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final extinct = controller.world.extinct;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.ink.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolButton(
            icon: Icons.colorize_outlined,
            label: 'Inspect & pipette',
            hint: 'Tap a microbe to follow it, or empty water to pipette in algae (1)',
            selected: controller.tool == Tool.hand,
            compact: compact,
            onTap: () => controller.setTool(Tool.hand),
          ),
          _ToolButton(
            icon: Icons.flare,
            label: 'UV pulse',
            hint: 'Tap to sterilise a circle of the drop with ultraviolet light (2)',
            selected: controller.tool == Tool.meteor,
            compact: compact,
            accent: Palette.terracotta,
            onTap: extinct ? null : () => controller.setTool(Tool.meteor),
          ),
          Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Palette.line),
          _ToolButton(
            icon: Icons.water_drop_outlined,
            label: 'Drain algae',
            hint: 'Filter most of the algae out of the drop',
            compact: compact,
            onTap: extinct ? null : controller.famine,
          ),
          _ToolButton(
            icon: Icons.grain,
            label: 'Add algae',
            hint: 'Add a fresh culture of algae across the drop',
            compact: compact,
            onTap: extinct ? null : controller.foodRain,
          ),
          Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Palette.line),
          _ToolButton(
            icon: Icons.menu_book_outlined,
            label: 'Guide',
            hint: controller.showGuide ? 'Hide the field guide' : 'What am I looking at?',
            selected: controller.showGuide,
            compact: compact,
            onTap: controller.toggleGuide,
          ),
          _ToolButton(
            icon: Icons.radar,
            label: 'Sense',
            hint: controller.showSense ? 'Hide sensing radii' : 'Draw every sensing radius',
            selected: controller.showSense,
            compact: compact,
            onTap: controller.toggleSense,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.selected = false,
    this.compact = false,
    this.accent = Palette.gold,
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;
  final bool selected;
  final bool compact;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Palette.faint : (selected ? Palette.surface : Palette.cream);
    return Tooltip(
      message: hint,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
