import 'package:flutter/painting.dart';

import '../sim/genome.dart';

/// Stain colours for families. All eight share one OKLCH lightness (0.57) and
/// chroma (0.105), so no family looks louder than another, and the hues skip
/// green, which belongs to algae.
const _stains = <Color>[
  Color(0xFFA75C7A), // raspberry, hue 355
  Color(0xFFAD5D54), // brick, hue 28
  Color(0xFFA56632), // amber, hue 58
  Color(0xFF967020), // ochre, hue 82
  Color(0xFF1F8893), // teal, hue 205
  Color(0xFF3B7DB1), // blue, hue 245
  Color(0xFF6970B4), // indigo, hue 278
  Color(0xFF91639F), // plum, hue 318
];

/// The stain colour of a family. Every founder gets one and passes it on;
/// neighbouring founders get hues far apart on the wheel.
Color familyColor(int family) => _stains[(family * 3 + 1) % _stains.length];

/// Made-up genus names, one per family.
const _genera = [
  'Wiggula', 'Glorbia', 'Pondella', 'Nibblaria', 'Driftella', 'Squirmis', 'Blobella', 'Flickera', //
  'Murkella', 'Gobbleria', 'Spindella', 'Twirlia', 'Bloopis', 'Smudgella', 'Zippula', 'Plinkia', //
  'Dozella', 'Fizzula', 'Grumblia', 'Wobblera', 'Sloshia', 'Puddla', 'Quiverna', 'Snorkella',
];

String genusOf(int family) => _genera[(family * 5 + 1) % _genera.length];

/// A Latin-ish name built from the genome: the family's genus, then a word for
/// each trait that stands out. "velox" means fast, "oculata" sharp-eyed.
String speciesName(int family, Genome genome) {
  final words = <(double, String)>[];
  void add(double strength, String word) {
    if (strength > 0) words.add((strength, word));
  }

  add(0.8 - genome.size, 'minuta');
  add(genome.size - 1.35, genome.size > 2 ? 'gigantea' : 'magna');
  add(0.8 - genome.speed, 'lenta');
  add((genome.speed - 1.35) / 1.2, genome.speed > 2.2 ? 'fulminans' : 'velox');
  add((30 - genome.sense) / 30, 'caeca');
  add((genome.sense - 58) / 60, genome.sense > 100 ? 'argus' : 'oculata');
  words.sort((a, b) => b.$1.compareTo(a.$1));
  final epithets = words.take(2).map((w) => w.$2).toList();
  return '${genusOf(family)} ${epithets.isEmpty ? 'vulgaris' : epithets.join(' ')}';
}

/// What the Latin words mean, for tooltips.
const epithetMeanings = {
  'vulgaris': 'common, nothing unusual',
  'minuta': 'tiny',
  'magna': 'large',
  'gigantea': 'giant',
  'lenta': 'slow',
  'velox': 'fast',
  'fulminans': 'lightning fast',
  'caeca': 'nearly blind',
  'oculata': 'sharp-eyed',
  'argus': 'sees almost everything',
};

String explainName(String name) {
  final words = name.split(' ').skip(1);
  return words.map((w) => '$w: ${epithetMeanings[w] ?? w}').join(' · ');
}
