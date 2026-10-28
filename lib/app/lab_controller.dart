import 'package:flutter/foundation.dart';

import '../sim/organism.dart';
import '../sim/sample.dart';
import '../sim/world.dart';
import '../sim/world_config.dart';

/// Owns the running world and the playback state. The screen calls [advance]
/// on every frame; painters listen to [frame], charts to [samples].
class LabController extends ChangeNotifier {
  LabController({Preset preset = Preset.temperate, int seed = 1})
    : _preset = preset,
      _config = preset.config.copyWith(seed: seed),
      _world = World(preset.config.copyWith(seed: seed));

  /// Builds a run from link parameters, e.g. `?preset=hunters&seed=3&at=300`
  /// opens the Hunters preset with seed 3, already five minutes in.
  factory LabController.fromQuery(Map<String, String> query) {
    final preset = Preset.values.where((p) => p.name == query['preset']?.toLowerCase()).firstOrNull ?? Preset.temperate;
    final seed = int.tryParse(query['seed'] ?? '') ?? 1;
    final controller = LabController(preset: preset, seed: seed);
    final at = double.tryParse(query['at'] ?? '');
    if (at != null && at > 0) {
      final seconds = at.clamp(0, 3600).toDouble();
      controller._world.step((seconds * controller._config.ticksPerSecond).round());
    }
    final speed = int.tryParse(query['speed'] ?? '');
    if (speed != null && speeds.contains(speed)) controller._speed = speed;
    return controller;
  }

  static const speeds = [1, 2, 4, 8, 16];

  /// Upper bound on ticks per frame, so a slow device never falls into a spiral.
  static const int maxTicksPerFrame = 240;

  World _world;
  WorldConfig _config;
  Preset? _preset;

  bool _playing = true;
  int _speed = 1;
  bool _showSense = false;
  Organism? _selected;
  double _pending = 0;
  double _lastSampleTime = -2;

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

  /// The inspected organism. It stays readable after it dies.
  Organism? get selected => _selected;

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

  /// Selects the organism under the point, or drops food if there is none.
  void tapField(double x, double y) {
    final hit = _world.organismAt(x, y);
    if (hit != null) {
      _selected = identical(hit, _selected) ? null : hit;
      notifyListeners();
    } else {
      _world.scatterFood(x, y);
    }
    _changed();
  }

  void clearSelection() {
    _selected = null;
    _changed();
    notifyListeners();
  }

  /// Starts a fresh run. A [preset] replaces the whole setup; a bare [config]
  /// marks the run as custom.
  void restart({WorldConfig? config, Preset? preset, int? seed}) {
    if (preset != null) {
      _preset = preset;
      _config = preset.config.copyWith(seed: seed ?? _config.seed);
    } else if (config != null) {
      _preset = null;
      _config = config.copyWith(seed: seed ?? config.seed);
    } else if (seed != null) {
      _config = _config.copyWith(seed: seed);
    }
    _world = World(_config);
    _selected = null;
    _pending = 0;
    _playing = true;
    _lastSampleTime = -2;
    _changed();
    notifyListeners();
  }

  void reseed() => restart(seed: _config.seed + 1);

  String exportCsv() => samplesToCsv(_world.history);

  void _changed() {
    frame.value++;
    final latest = _world.history.isEmpty ? -1.0 : _world.history.last.time;
    if (latest != _lastSampleTime) {
      _lastSampleTime = latest;
      samples.value++;
    }
  }

  @override
  void dispose() {
    frame.dispose();
    samples.dispose();
    super.dispose();
  }
}
