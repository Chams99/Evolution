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
      MilestoneTone.good => Palette.food,
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

/// Current season and food supply, shown only when seasons are on.
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
            ? ('DRY SEASON', Palette.terracotta)
            : supply > 1.25
            ? ('WET SEASON', Palette.food)
            : ('MILD SEASON', Palette.gold);
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
          decoration: BoxDecoration(
            color: Palette.ink.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Styles.label.copyWith(fontSize: 10, color: color)),
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
            icon: Icons.touch_app_outlined,
            label: 'Inspect & feed',
            hint: 'Tap an organism to follow it, or empty ground to drop food (1)',
            selected: controller.tool == Tool.hand,
            compact: compact,
            onTap: () => controller.setTool(Tool.hand),
          ),
          _ToolButton(
            icon: Icons.flare,
            label: 'Meteor',
            hint: 'Tap to wipe out everything in a circle (2)',
            selected: controller.tool == Tool.meteor,
            compact: compact,
            accent: Palette.terracotta,
            onTap: extinct ? null : () => controller.setTool(Tool.meteor),
          ),
          Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Palette.line),
          _ToolButton(
            icon: Icons.grass,
            label: 'Famine',
            hint: 'Destroy most of the food on the ground',
            compact: compact,
            onTap: extinct ? null : controller.famine,
          ),
          _ToolButton(
            icon: Icons.grain,
            label: 'Food rain',
            hint: 'Scatter fresh food across the field',
            compact: compact,
            onTap: extinct ? null : controller.foodRain,
          ),
          Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Palette.line),
          _ToolButton(
            icon: Icons.radar,
            label: 'Sense',
            hint: controller.showSense ? 'Hide sensing radii' : 'Draw every sensing radius',
            selected: controller.showSense,
            compact: compact,
            accent: Palette.steel,
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
