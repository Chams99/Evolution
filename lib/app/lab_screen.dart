import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'lab_controller.dart';
import 'theme.dart';
import 'widgets/charts.dart';
import 'widgets/field_view.dart';
import 'widgets/panels.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key, this.controller});

  /// Injected in tests; the screen creates its own otherwise.
  final LabController? controller;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> with SingleTickerProviderStateMixin {
  late final LabController _controller = widget.controller ?? LabController.fromQuery(Uri.base.queryParameters);
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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= _wideBreakpoint ? _wide(context) : _narrow(context, constraints),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
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
                    Expanded(child: _Title(controller: _controller)),
                    Readouts(controller: _controller),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Center(child: _Field(controller: _controller)),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: TransportBar(controller: _controller)),
                    const _Legend(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          SizedBox(
            width: 372,
            child: ListView(
              padding: const EdgeInsets.only(top: 4),
              children: [
                InspectorPanel(controller: _controller),
                ChartsPanel(controller: _controller),
                SetupPanel(controller: _controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context, BoxConstraints constraints) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _Title(controller: _controller, compact: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Field(controller: _controller),
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
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TransportBar(controller: _controller, compact: constraints.maxWidth < 600),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'CHARTS'),
              Tab(text: 'ORGANISM'),
              Tab(text: 'SETUP'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [ChartsPanel(controller: _controller)],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    InspectorPanel(controller: _controller),
                    const _Legend(),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [SetupPanel(controller: _controller)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.controller, this.compact = false});

  final LabController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final preset = controller.preset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${preset?.label.toUpperCase() ?? 'CUSTOM'} · SEED ${controller.config.seed}',
          style: Styles.label.copyWith(color: Palette.terracotta),
        ),
        const SizedBox(height: 4),
        Text('Evolution', style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: compact ? 24 : 30)),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            'Organisms inherit size, speed and sense, pay for them in energy, and adapt.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller});

  final LabController controller;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    return Stack(
      children: [
        FieldView(controller: controller),
        if (world.extinct)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                decoration: BoxDecoration(
                  color: Palette.ink.withValues(alpha: 0.92),
                  border: Border.all(color: Palette.lineStrong),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('EXTINCT', style: Styles.label.copyWith(color: Palette.terracotta)),
                    const SizedBox(height: 6),
                    Text(
                      'The last organism died at ${formatClock(world.seconds)}, '
                      'after ${world.totalBirths} births.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: controller.restart, child: const Text('Restart')),
                        const SizedBox(width: 6),
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Styles.label.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: Palette.faint);
    Widget dot(Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot(Palette.terracotta, 8),
              const SizedBox(width: 3),
              dot(Palette.gold, 8),
              const SizedBox(width: 6),
              Text('SLOW → FAST', style: style),
            ],
          ),
          Text('RADIUS = SIZE', style: style),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot(Palette.food, 5),
              const SizedBox(width: 6),
              Text('FOOD', style: style),
            ],
          ),
        ],
      ),
    );
  }
}
