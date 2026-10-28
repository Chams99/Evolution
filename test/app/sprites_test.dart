import 'package:evolution/app/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the figures load at three sizes and the view picks the closest one', (tester) async {
    await tester.runAsync(Sprites.load);
    final sprites = Sprites.current.value;
    expect(sprites, isNotNull);
    expect(sprites!.levels.map((l) => l.factor), [1.0, 0.5, 0.25]);
    for (final level in sprites.levels) {
      expect(level.cellTint.width, closeTo(Sprites.frameWidth * 3 * level.factor, 1));
      expect(level.cellTint.height, closeTo(Sprites.frameHeight * level.factor, 1));
      expect(level.cellOverlay.width, level.cellTint.width);
      expect(level.algae.width, closeTo(Sprites.algaeFrame * 3 * level.factor, 1));
    }
    expect(sprites.forCell(12).factor, 0.25);
    expect(sprites.forCell(30).factor, 0.5);
    expect(sprites.forCell(200).factor, 1.0);
  });

  test('cells show more stored energy, then division', () {
    expect(Sprites.stateFor(0.1), 0);
    expect(Sprites.stateFor(0.6), 1);
    expect(Sprites.stateFor(0.95), 2);
  });
}
