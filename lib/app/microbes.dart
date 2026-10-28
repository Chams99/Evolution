import 'package:flutter/painting.dart';

import '../sim/genome.dart';

/// Stain colours for families, chosen to read on the bright slide and on the
/// dark panels alike.
const _stains = <Color>[
  Color(0xFF8A5BB0), // violet
  Color(0xFFC0507E), // magenta
  Color(0xFF2E8C83), // teal
  Color(0xFFC7842A), // amber
  Color(0xFFB65238), // rust
  Color(0xFF4A62B0), // indigo
  Color(0xFF8E3B4E), // burgundy
  Color(0xFFCF6F86), // rose
  Color(0xFF5A7180), // slate
  Color(0xFF9A4E86), // plum
  Color(0xFFB07A3A), // ochre
  Color(0xFF3F7FA8), // cerulean
];

/// The stain colour of a family. Every founder gets one and passes it on.
Color familyColor(int family) => _stains[(family * 7 + 3) % _stains.length];

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
