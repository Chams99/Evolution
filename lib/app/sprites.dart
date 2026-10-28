import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One resolution of the rendered figures (see tool/render_sprites.py).
///
/// Cell frames face +x. The body layer is greyscale and gets tinted with the
/// family stain; the overlay keeps its own colours.
class SpriteLevel {
  const SpriteLevel(this.factor, this.cellTint, this.cellOverlay, this.ghost, this.algae);

  /// Size relative to the full-resolution figures.
  final double factor;
  final ui.Image cellTint;
  final ui.Image cellOverlay;
  final ui.Image ghost;
  final ui.Image algae;

  double get cellX => Sprites.cellX * factor;
  double get cellY => Sprites.cellY * factor;
  double get cellHalfLength => Sprites.cellHalfLength * factor;
  double get algaeCentre => Sprites.algaeFrame * factor / 2;
  double get algaeRadius => Sprites.algaeRadius * factor;

  /// Frame for a cell in a given state: 0 hungry, 1 fed, 2 dividing.
  ui.Rect cellFrame(int state) => ui.Rect.fromLTWH(
    state * Sprites.frameWidth * factor,
    0,
    Sprites.frameWidth * factor,
    Sprites.frameHeight * factor,
  );

  ui.Rect get ghostFrame => ui.Rect.fromLTWH(0, 0, Sprites.frameWidth * factor, Sprites.frameHeight * factor);

  ui.Rect algaeFrame(int variant) => ui.Rect.fromLTWH(
    variant * Sprites.algaeFrame * factor,
    0,
    Sprites.algaeFrame * factor,
    Sprites.algaeFrame * factor,
  );
}

/// The figures at full, half and quarter size. Drawing from the level closest
/// to the on-screen size keeps outlines smooth instead of broken into dots.
class Sprites {
  Sprites._(this.levels);

  /// Largest first.
  final List<SpriteLevel> levels;

  /// Full-resolution frame layout, in sprite pixels.
  static const double frameWidth = 192;
  static const double frameHeight = 128;
  static const double cellX = 100;
  static const double cellY = 64;
  static const double cellHalfLength = 70;
  static const double algaeFrame = 64;
  static const double algaeRadius = 21;

  static const _levels = {'': 1.0, '@half': 0.5, '@quarter': 0.25};

  /// Null until the images have loaded; painters fall back to vector drawing.
  static final ValueNotifier<Sprites?> current = ValueNotifier(null);

  static Future<void>? _loading;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final levels = <SpriteLevel>[];
      for (final MapEntry(key: suffix, value: factor) in _levels.entries) {
        final images = await Future.wait([
          _image('assets/sprites/cell_tint$suffix.png'),
          _image('assets/sprites/cell_overlay$suffix.png'),
          _image('assets/sprites/cell_ghost$suffix.png'),
          _image('assets/sprites/algae$suffix.png'),
        ]);
        levels.add(SpriteLevel(factor, images[0], images[1], images[2], images[3]));
      }
      current.value = Sprites._(levels);
    } catch (error) {
      debugPrint('Microbe figures could not be loaded, using vector drawings: $error');
    }
  }

  static Future<ui.Image> _image(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  /// The smallest level that is still at least as large as the cell on screen.
  SpriteLevel forCell(double halfLengthOnScreen) {
    for (final level in levels.reversed) {
      if (level.cellHalfLength >= halfLengthOnScreen * 0.9) return level;
    }
    return levels.first;
  }

  SpriteLevel forAlgae(double radiusOnScreen) {
    for (final level in levels.reversed) {
      if (level.algaeRadius >= radiusOnScreen * 0.9) return level;
    }
    return levels.first;
  }

  /// State shown for a given share of the energy needed to divide.
  static int stateFor(double energyShare) => energyShare > 0.88 ? 2 : (energyShare > 0.45 ? 1 : 0);
}
