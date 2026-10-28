import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'lab_controller.dart';
import 'progress_store.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/field_guide.dart';
import 'widgets/field_overlays.dart';
import 'widgets/field_view.dart';
import 'widgets/intro.dart';
import 'widgets/learn.dart';
import 'widgets/panels.dart';
import 'widgets/setup_panel.dart';
import 'widgets/trait_strip.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key, this.controller});

  /// Injected in tests; the screen creates its own otherwise.
  final LabController? controller;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with SingleTickerProviderStateMixin {
  late final LabController _controller =
      widget.controller ?? LabController.fromQuery(Uri.base.queryParameters, store: PrefsProgressStore());
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  static const _wideBreakpoint = 980.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _ticker = createTicker((elapsed) {
      final delta = elapsed - _last;
      _last = elapsed;
      _controller.advance(delta > const Duration(milliseconds: 100) ? const Duration(milliseconds: 100) : delta);
    })..start();
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _ticker.dispose();
    _controller.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _controller.togglePlaying,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _controller.stepSecond,
        const SingleActivator(LogicalKeyboardKey.keyR): _controller.restart,
        const SingleActivator(LogicalKeyboardKey.digit1): () => _controller.setTool(Tool.hand),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _controller.setTool(Tool.meteor),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= _wideBreakpoint ? _wide(context) : _narrow(context, constraints),
                ),
              ),
              if (_controller.showIntro) Positioned.fill(child: IntroOverlay(controller: _controller)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final gutter = size.width >= 1600 ? 32.0 : 22.0;
    final panelWidth = (size.width * 0.27).clamp(320.0, 420.0);
    final short = size.height < 820;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, short ? 14 : 20, gutter, short ? 12 : 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _Title(controller: _controller, compact: short),
                    ),
                    Readouts(controller: _controller),
                  ],
                ),
                SizedBox(height: short ? 10 : 14),
                Expanded(
                  child: Center(child: _Field(controller: _controller)),
                ),
                const SizedBox(height: 10),
                _ControlDeck(controller: _controller),
                const SizedBox(height: 10),
                FieldCaption(controller: _controller),
                const SizedBox(height: 10),
                TraitStrip(controller: _controller),
              ],
            ),
          ),
          SizedBox(width: gutter),
          SizedBox(
            width: panelWidth,
            child: DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_controller.lesson != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: SingleChildScrollView(child: LessonStrip(controller: _controller)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_controller.selected != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: _controller.lesson != null ? 240 : 360),
                      child: SingleChildScrollView(child: InspectorPanel(controller: _controller)),
                    ),
                  const TabBar(
                    tabs: [
                      Tab(text: 'LEARN'),
                      Tab(text: 'CHARTS'),
                      Tab(text: 'SETUP'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.only(top: 18),
                          children: [
                            FieldGuide(controller: _controller, overlay: false),
                            const SizedBox(height: 22),
                            LessonList(controller: _controller),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.only(top: 18),
                          children: [
                            if (_controller.selected == null) InspectorPanel(controller: _controller),
                            ChartsPanel(controller: _controller),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.only(top: 18),
                          children: [SetupPanel(controller: _controller)],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context, BoxConstraints constraints) {
    final compact = constraints.maxWidth < 600;
    return DefaultTabController(
      length: 4,
      initialIndex: 1,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: _Title(controller: _controller, compact: true),
                ),
                if (_controller.lesson != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: LessonStrip(controller: _controller),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Field(controller: _controller, compact: compact),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Center(
                    child: ToolDock(controller: _controller, compact: compact),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: FieldCaption(controller: _controller),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Readouts(controller: _controller),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: TraitStrip(controller: _controller),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: TransportBar(controller: _controller, compact: compact),
                ),
              ],
            ),
          ),
          const SliverPersistentHeader(pinned: true, delegate: _TabsHeader()),
        ],
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FieldGuide(controller: _controller, overlay: false),
                const SizedBox(height: 22),
                LessonList(controller: _controller),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [ChartsPanel(controller: _controller)],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [InspectorPanel(controller: _controller)],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [SetupPanel(controller: _controller)],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader();

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const ColoredBox(
      color: Palette.ink,
      child: TabBar(
        tabs: [
          Tab(text: 'LEARN'),
          Tab(text: 'CHARTS'),
          Tab(text: 'SPECIMEN'),
          Tab(text: 'SETUP'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader oldDelegate) => false;
}

class _Title extends StatelessWidget {
  const _Title({required this.controller, this.compact = false});

  final LabController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final preset = controller.preset;
    final lesson = controller.lesson;
    final setup = lesson != null ? 'LESSON' : (preset?.label.toUpperCase() ?? 'CUSTOM');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$setup · SEED ${controller.config.seed}', style: Styles.label.copyWith(color: Palette.terracotta)),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Evolution', style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: compact ? 24 : 30)),
            const SizedBox(width: 6),
            Tooltip(
              message: 'How it works',
              child: IconButton(
                onPressed: controller.reopenIntro,
                icon: const Icon(Icons.help_outline, size: 19),
                color: Palette.faint,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        if (!compact)
          Text(
            'A live drop of pond water. Microbes eat, divide, mutate, and slowly become something new.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, this.compact = false});

  final LabController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    return Stack(
      children: [
        FieldView(controller: controller),
        Positioned.fill(
          child: IgnorePointer(
            child: MicroscopeHud(controller: controller, label: controller.sampleLabel),
          ),
        ),
        Positioned(
          left: 12,
          top: compact ? 40 : 44,
          right: 120,
          child: MilestoneFeed(controller: controller, compact: compact),
        ),
        Positioned(right: 10, top: 10, child: SeasonBadge(controller: controller)),
        if (world.extinct)
          Positioned.fill(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                decoration: BoxDecoration(
                  color: Palette.ink.withValues(alpha: 0.92),
                  border: Border.all(color: Palette.lineStrong),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('STERILE', style: Styles.label.copyWith(color: Palette.terracotta)),
                    const SizedBox(height: 6),
                    Text(
                      'The last microbe died at ${formatClock(world.seconds)}, after ${world.totalBirths} divisions.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(onPressed: controller.restart, child: const Text('Restart')),
                        FilledButton(
                          onPressed: controller.reseed,
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.gold,
                            foregroundColor: Palette.surface,
                          ),
                          child: const Text('Try another seed'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Playback on the left, lab tools on the right, under the live view.
class _ControlDeck extends StatelessWidget {
  const _ControlDeck({required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One row only when the transport bar and the tools both fit unwrapped.
        if (constraints.maxWidth >= 1200) {
          return Row(
            children: [
              Expanded(child: TransportBar(controller: controller)),
              const SizedBox(width: 12),
              ToolDock(controller: controller),
            ],
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            TransportBar(controller: controller),
            ToolDock(controller: controller, compact: constraints.maxWidth < 640),
          ],
        );
      },
    );
  }
}
