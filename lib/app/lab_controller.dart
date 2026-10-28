import 'package:flutter/foundation.dart';

import '../sim/genome.dart';
import '../sim/organism.dart';
import '../sim/sample.dart';
import '../sim/world.dart';
import '../sim/world_config.dart';
import 'lessons.dart';
import 'progress_store.dart';

/// What a tap on the field does.
enum Tool {
  /// Select an organism, or drop food on empty ground.
  hand,

  /// Strike everything within a radius.
  meteor,
}

enum MilestoneTone { neutral, good, bad }

class Milestone {
  Milestone(this.text, this.tone, this.time) : shownAt = DateTime.now();

  final String text;
  final MilestoneTone tone;

  /// Simulated time of the event.
  final double time;

  /// Wall-clock time it was raised, so the field can fade it out.
  final DateTime shownAt;
}

/// The lesson being played, with its live progress.
class LessonRun {
  LessonRun(this.lesson);

  final Lesson lesson;
  final Map<String, double> memory = {};
  LessonProgress progress = const LessonProgress(0, '');
  bool completed = false;
}

/// Owns the running world and the playback state. The screen calls [advance]
/// on every frame; painters listen to [frame], charts to [samples].
class LabController extends ChangeNotifier {
  LabController({Preset preset = Preset.temperate, int seed = 1, ProgressStore? store})
    : _preset = preset,
      _config = preset.config.copyWith(seed: seed),
      _world = World(preset.config.copyWith(seed: seed)),
      _store = store ?? MemoryProgressStore(seen: true) {
    _resetTrackers();
    _loadProgress();
  }

  /// Builds a run from link parameters, e.g. `?preset=hunters&seed=3&at=300`
  /// opens the Hunters preset with seed 3, already five minutes in.
  factory LabController.fromQuery(Map<String, String> query, {ProgressStore? store}) {
    final preset = Preset.values.where((p) => p.name == query['preset']?.toLowerCase()).firstOrNull ?? Preset.temperate;
    final seed = int.tryParse(query['seed'] ?? '') ?? 1;
    final controller = LabController(preset: preset, seed: seed, store: store);
    final at = double.tryParse(query['at'] ?? '');
    if (at != null && at > 0) {
      final seconds = at.clamp(0, 3600).toDouble();
      controller._world.step((seconds * controller._config.ticksPerSecond).round());
      controller._resetTrackers();
    }
    final speed = int.tryParse(query['speed'] ?? '');
    if (speed != null && speeds.contains(speed)) controller._speed = speed;
    final lesson = lessons.where((l) => l.id == query['lesson']).firstOrNull;
    if (lesson != null) {
      controller.startLesson(lesson);
      if (at != null && at > 0) {
        controller._world.step((at.clamp(0, 3600) * controller._config.ticksPerSecond).round());
        controller._resetTrackers();
      }
    }
    // Someone opening a link to a specific run came for that run, not the tour.
    if (query.keys.any(const {'preset', 'seed', 'at', 'lesson'}.contains)) controller._skipIntro = true;
    return controller;
  }

  static const speeds = [1, 2, 4, 8, 16];

  /// Upper bound on ticks per frame, so a slow device never falls into a spiral.
  static const int maxTicksPerFrame = 240;

  /// Smoothing for the selection readings, per sample.
  static const double _selectionSmoothing = 0.25;

  World _world;
  WorldConfig _config;
  Preset? _preset;
  final ProgressStore _store;

  bool _playing = true;
  int _speed = 1;
  bool _showSense = false;
  Tool _tool = Tool.hand;
  Organism? _selected;
  double _pending = 0;
  double _lastSampleTime = -2;

  LessonRun? _lesson;
  Set<String> _completed = {};
  bool _introSeen = true;
  bool _skipIntro = false;
  bool _progressLoaded = false;

  final List<Milestone> milestones = [];
  final Map<Trait, double?> _selection = {for (final t in Trait.values) t: null};

  // Milestone trackers.
  int _generationMark = 0;
  int _populationMark = 0;
  int _kills = 0;
  bool _selectedDeathReported = false;
  final Map<Trait, int> _traitMarks = {};

  /// Bumped whenever the world changes.
  final ValueNotifier<int> frame = ValueNotifier(0);

  /// Bumped whenever a new sample is recorded.
  final ValueNotifier<int> samples = ValueNotifier(0);

  World get world => _world;
  WorldConfig get config => _config;
  Preset? get preset => _preset;
  bool get playing => _playing && !_world.extinct;
  int get speed => _speed;
  bool get showSense => _showSense;
  Tool get tool => _tool;
  LessonRun? get lesson => _lesson;
  Set<String> get completedLessons => _completed;
  bool get progressLoaded => _progressLoaded;

  /// True until the first-run introduction has been dismissed.
  bool get showIntro => _progressLoaded && !_introSeen && !_skipIntro;

  /// The inspected organism. It stays readable after it dies.
  Organism? get selected => _selected;

  /// Smoothed selection differential per trait (see [World.selection]).
  double? selectionOf(Trait trait) => _selection[trait];

  Future<void> _loadProgress() async {
    final completed = await _store.completedLessons();
    final introSeen = await _store.introSeen();
    if (_disposed) return;
    _completed = {..._completed, ...completed};
    _introSeen = introSeen;
    _progressLoaded = true;
    notifyListeners();
  }

  void dismissIntro() {
    _introSeen = true;
    _store.saveIntroSeen();
    notifyListeners();
  }

  void reopenIntro() {
    _introSeen = false;
    _skipIntro = false;
    notifyListeners();
  }

  void advance(Duration delta) {
    if (!playing) return;
    _pending += delta.inMicroseconds / Duration.microsecondsPerSecond * _config.ticksPerSecond * _speed;
    final ticks = _pending.floor().clamp(0, maxTicksPerFrame).toInt();
    _pending = (_pending - ticks).clamp(0, 1).toDouble();
    if (ticks == 0) return;
    _world.step(ticks);
    _changed();
    if (_world.extinct) notifyListeners();
  }

  void togglePlaying() {
    if (_world.extinct) return;
    _playing = !_playing;
    _pending = 0;
    notifyListeners();
  }

  /// Advances exactly one simulated second.
  void stepSecond() {
    if (_world.extinct) return;
    _playing = false;
    _world.step(_config.ticksPerSecond);
    _changed();
    notifyListeners();
  }

  void setSpeed(int value) {
    _speed = value;
    notifyListeners();
  }

  void toggleSense() {
    _showSense = !_showSense;
    _changed();
    notifyListeners();
  }

  void setTool(Tool tool) {
    _tool = tool;
    notifyListeners();
  }

  /// Applies the current tool at a point in world coordinates.
  void tapField(double x, double y) {
    switch (_tool) {
      case Tool.meteor:
        final killed = _world.strike(x, y);
        _milestone(
          killed == 0 ? 'Meteor hit empty ground' : 'Meteor strike: $killed organism${killed == 1 ? '' : 's'} lost',
          killed == 0 ? MilestoneTone.neutral : MilestoneTone.bad,
        );
        _refreshLesson();
        notifyListeners();
      case Tool.hand:
        final hit = _world.organismAt(x, y);
        if (hit != null) {
          _selected = identical(hit, _selected) ? null : hit;
          _selectedDeathReported = false;
          notifyListeners();
        } else {
          _world.scatterFood(x, y);
        }
    }
    _changed();
  }

  void famine() {
    final removed = _world.famine();
    _milestone('Famine: $removed food items destroyed', MilestoneTone.bad);
    _changed();
    notifyListeners();
  }

  void foodRain() {
    _world.foodRain();
    _milestone('Food rain across the whole field', MilestoneTone.good);
    _changed();
    notifyListeners();
  }

  void clearSelection() {
    _selected = null;
    _changed();
    notifyListeners();
  }

  /// Starts a fresh run. A [preset] replaces the whole setup; a bare [config]
  /// marks the run as custom. Leaving a lesson's setup ends the lesson.
  void restart({WorldConfig? config, Preset? preset, int? seed, bool keepLesson = false}) {
    if (preset != null) {
      _preset = preset;
      _config = preset.config.copyWith(seed: seed ?? _config.seed);
    } else if (config != null) {
      _preset = null;
      _config = config.copyWith(seed: seed ?? config.seed);
    } else if (seed != null) {
      _config = _config.copyWith(seed: seed);
    }
    if (!keepLesson && (preset != null || config != null)) _lesson = null;
    final run = _lesson;
    if (run != null) {
      run.memory.clear();
      run.completed = false;
    }
    _world = World(_config);
    _selected = null;
    _pending = 0;
    _playing = true;
    _lastSampleTime = -2;
    milestones.clear();
    _resetTrackers();
    _refreshLesson();
    _changed();
    notifyListeners();
  }

  void reseed() => restart(seed: _config.seed + 1);

  void startLesson(Lesson lesson) {
    _lesson = LessonRun(lesson);
    _preset = lesson.preset;
    _config = lesson.config;
    _tool = lesson.usesMeteor ? Tool.meteor : Tool.hand;
    restart(keepLesson: true);
  }

  void leaveLesson() {
    _lesson = null;
    _tool = Tool.hand;
    notifyListeners();
  }

  /// The lesson after the current one, if there is one.
  Lesson? get nextLesson {
    final run = _lesson;
    if (run == null) return null;
    final index = lessons.indexOf(run.lesson);
    return index >= 0 && index + 1 < lessons.length ? lessons[index + 1] : null;
  }

  String exportCsv() => samplesToCsv(_world.history);

  /// One plain sentence about what selection is doing right now.
  String get insight {
    if (_world.extinct) return 'The population is extinct. Every lineage ended.';
    if (_world.organisms.length < 6) return 'Too few organisms left to say what is being selected.';
    Trait? strongest;
    var strength = 0.0;
    for (final trait in Trait.values) {
      final s = _selection[trait];
      if (s != null && s.abs() > strength) {
        strongest = trait;
        strength = s.abs();
      }
    }
    final supply = _world.foodSupply;
    if (strongest == null || strength < 0.2) {
      if (supply < 0.6) {
        return 'Dry season. Food is scarce, and the organisms with the least stored energy are starving.';
      }
      if (supply > 1.4) {
        return 'Wet season. Food is plentiful, so almost everyone reproduces and selection is weak.';
      }
      return 'No trait is clearly favoured right now. Changes are mostly down to chance.';
    }
    final favoured = (_selection[strongest] ?? 0) > 0;
    final who = switch ((strongest, favoured)) {
      (Trait.size, true) => 'Larger organisms',
      (Trait.size, false) => 'Smaller organisms',
      (Trait.speed, true) => 'Faster organisms',
      (Trait.speed, false) => 'Slower, thriftier organisms',
      (Trait.sense, true) => 'Organisms that sense further',
      (Trait.sense, false) => 'Organisms with shorter, cheaper senses',
    };
    return '$who are leaving the most offspring right now, so their traits are spreading.';
  }

  void _changed() {
    frame.value++;
    final latest = _world.history.isEmpty ? -1.0 : _world.history.last.time;
    if (latest != _lastSampleTime) {
      _lastSampleTime = latest;
      _onSample();
      samples.value++;
    }
  }

  void _onSample() {
    for (final trait in Trait.values) {
      final reading = _world.selection(trait);
      final previous = _selection[trait];
      _selection[trait] = reading == null
          ? (previous == null ? null : previous * (1 - _selectionSmoothing))
          : previous == null
          ? reading
          : previous + (reading - previous) * _selectionSmoothing;
    }
    _checkMilestones();
    _refreshLesson();
  }

  void _resetTrackers() {
    _generationMark = _world.maxGeneration;
    _populationMark = _world.organisms.length;
    _kills = _world.totalKills;
    _traitMarks.clear();
    for (final trait in Trait.values) {
      _selection[trait] = null;
    }
  }

  void _checkMilestones() {
    final world = _world;
    final history = world.history;
    if (history.isEmpty) return;
    final now = history.last;

    const generations = [5, 10, 25, 50, 100, 200, 500];
    for (final g in generations) {
      if (now.maxGeneration >= g && _generationMark < g) {
        _milestone('Generation $g reached', MilestoneTone.good);
      }
    }
    _generationMark = now.maxGeneration;

    const populations = [50, 100, 200, 300, 400];
    for (final p in populations) {
      if (now.population >= p && _populationMark < p) _milestone('Population passed $p', MilestoneTone.good);
    }
    _populationMark = now.population;

    if (history.length > 30) {
      final window = history.sublist(history.length - 31);
      final peak = window.fold<int>(0, (m, s) => s.population > m ? s.population : m);
      final crashedRecently = milestones.any((m) => m.text.startsWith('Population crashed') && now.time - m.time < 40);
      if (peak >= 20 && now.population <= peak * 0.5 && !crashedRecently) {
        final drop = ((1 - now.population / peak) * 100).round();
        final context = now.foodSupply < 0.8 ? ' in the dry season' : '';
        _milestone('Population crashed $drop%$context', MilestoneTone.bad);
      }
    }

    if (world.totalKills > 0 && _kills == 0) _milestone('First predator kill', MilestoneTone.bad);
    _kills = world.totalKills;

    final start = history.first;
    for (final trait in Trait.values) {
      final base = start.traits[trait]!.mean;
      if (base == 0 || now.population == 0) continue;
      final change = now.traits[trait]!.mean / base - 1;
      final step = (change.abs() / 0.25).floor() * change.sign.toInt();
      final mark = _traitMarks[trait] ?? 0;
      if (step.abs() > mark.abs() && step.sign == (mark == 0 ? step.sign : mark.sign)) {
        final word = switch (trait) {
          Trait.size => 'size',
          Trait.speed => 'speed',
          Trait.sense => 'sense',
        };
        _milestone(
          'Average $word ${change > 0 ? 'up' : 'down'} ${(change.abs() * 100).round()}% since the start',
          MilestoneTone.neutral,
        );
        _traitMarks[trait] = step;
      }
    }

    final pick = _selected;
    if (pick != null && !pick.alive && !_selectedDeathReported) {
      _selectedDeathReported = true;
      final how = switch (pick.deathCause!) {
        DeathCause.starvation => 'starved',
        DeathCause.oldAge => 'died of old age',
        DeathCause.predation => 'was eaten',
        DeathCause.disaster => 'was killed by a meteor',
      };
      final family = world.livingDescendants(pick.id);
      _milestone(
        '#${pick.id} $how${family > 0 ? ', leaving $family living descendant${family == 1 ? '' : 's'}' : ''}',
        MilestoneTone.neutral,
      );
    }

    if (world.extinct) _milestone('Extinct after ${now.time.round()} seconds', MilestoneTone.bad);
  }

  void _refreshLesson() {
    final run = _lesson;
    if (run == null || run.completed || _world.history.isEmpty) return;
    run.progress = run.lesson.evaluate(_world, run.memory);
    if (run.progress.done) {
      run.completed = true;
      _completed = {..._completed, run.lesson.id};
      _store.saveCompletedLessons(_completed);
      _milestone('Lesson complete: ${run.lesson.title}', MilestoneTone.good);
      notifyListeners();
    }
  }

  void _milestone(String text, MilestoneTone tone) {
    milestones.add(Milestone(text, tone, _world.seconds));
    if (milestones.length > 40) milestones.removeAt(0);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    frame.dispose();
    samples.dispose();
    super.dispose();
  }
}
