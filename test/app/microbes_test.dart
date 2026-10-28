import 'package:evolution/app/microbes.dart';
import 'package:evolution/sim/genome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an ordinary microbe is vulgaris, an unusual one is named for what stands out', () {
    expect(speciesName(0, const Genome(size: 1, speed: 1, sense: 40)), endsWith(' vulgaris'));
    expect(speciesName(0, const Genome(size: 1, speed: 2, sense: 40)), endsWith(' velox'));
    expect(
      speciesName(0, const Genome(size: 2.4, speed: 1, sense: 140)).split(' ').skip(1),
      unorderedEquals(['gigantea', 'argus']),
    );
    expect(speciesName(0, const Genome(size: 0.5, speed: 0.5, sense: 12)).split(' '), hasLength(3));
  });

  test('a family keeps its genus and colour whatever its traits do', () {
    final a = speciesName(7, const Genome(size: 1, speed: 1, sense: 40)).split(' ').first;
    final b = speciesName(7, const Genome(size: 2, speed: 3, sense: 150)).split(' ').first;
    expect(a, b);
    expect(familyColor(7), familyColor(7));
    expect({for (var f = 0; f < 12; f++) familyColor(f)}.length, 12);
  });

  test('every Latin word can be explained', () {
    final name = speciesName(3, const Genome(size: 2.4, speed: 2.6, sense: 12));
    expect(explainName(name), isNot(contains('null')));
    for (final word in name.split(' ').skip(1)) {
      expect(epithetMeanings, contains(word));
    }
  });
}
