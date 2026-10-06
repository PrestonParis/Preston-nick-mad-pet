import 'package:digital_pet/pet_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clamping', () {
    test('feed at hunger 5 keeps hunger at 0 and applies overfed rule', () {
      final s = PetRules.feed(const PetState(hunger: 5, happiness: 50));
      expect(s.hunger, 0);
      expect(s.happiness, 30); // resulting hunger 0 < 30 -> -20
    });

    test('feed at hunger 95 lowers hunger and raises happiness', () {
      final s = PetRules.feed(const PetState(hunger: 95, happiness: 50));
      expect(s.hunger, 85);
      expect(s.happiness, 60);
    });

    test('play at happiness 95 clamps to 100', () {
      final s = PetRules.play(const PetState(happiness: 95, hunger: 50));
      expect(s.happiness, 100);
      expect(s.hunger, 55);
    });

    test('play at hunger 98 clamps hunger to 100', () {
      expect(PetRules.play(const PetState(hunger: 98)).hunger, 100);
    });
  });

  group('mood bands', () {
    Mood moodAt(int h) => PetState(happiness: h).mood;
    test('29 unhappy, 30 neutral, 70 neutral, 71 happy', () {
      expect(moodAt(29), Mood.unhappy);
      expect(moodAt(30), Mood.neutral);
      expect(moodAt(70), Mood.neutral);
      expect(moodAt(71), Mood.happy);
    });

    test('exactly 80 does not qualify for win; 81 does', () {
      expect(const PetState(happiness: 80).qualifiesForWin, isFalse);
      expect(const PetState(happiness: 81).qualifiesForWin, isTrue);
    });
  });

  group('hunger ticks', () {
    test('95 -> 100 has no penalty, next tick clamps and costs 20', () {
      var s = const PetState(hunger: 95, happiness: 50);
      s = PetRules.hungerTick(s);
      expect(s.hunger, 100);
      expect(s.happiness, 50);
      s = PetRules.hungerTick(s);
      expect(s.hunger, 100);
      expect(s.happiness, 30);
    });
  });

  group('outcomes', () {
    test('hunger 100 and happiness 10 is a loss', () {
      final s = PetRules.hungerTick(const PetState(hunger: 100, happiness: 30));
      expect(s.happiness, 10);
      expect(s.outcome, Outcome.lost);
    });

    test('happiness 11 at hunger 100 is not a loss', () {
      final s = PetRules.hungerTick(const PetState(hunger: 100, happiness: 31));
      expect(s.outcome, Outcome.playing);
    });

    test('actions do nothing after an outcome', () {
      const lost = PetState(hunger: 100, happiness: 10, outcome: Outcome.lost);
      expect(identical(PetRules.feed(lost), lost), isTrue);
      expect(identical(PetRules.play(lost), lost), isTrue);
      expect(identical(PetRules.hungerTick(lost), lost), isTrue);
    });

    test('win only applies while happiness is above 80', () {
      expect(PetRules.win(const PetState(happiness: 80)).outcome,
          Outcome.playing);
      expect(PetRules.win(const PetState(happiness: 81)).outcome, Outcome.won);
    });

    test('reset restores meters and outcome but keeps name', () {
      final s = PetRules.reset(const PetState(
          name: 'Mochi', happiness: 5, hunger: 100, outcome: Outcome.lost));
      expect(s.name, 'Mochi');
      expect(s.happiness, 50);
      expect(s.hunger, 50);
      expect(s.outcome, Outcome.playing);
    });
  });

  test('rename ignores blank names and trims', () {
    expect(PetRules.rename(const PetState(), '   ').name, 'Pip');
    expect(PetRules.rename(const PetState(), '  Mochi ').name, 'Mochi');
  });

  test('message is derived from state', () {
    expect(petMessage(const PetState(outcome: Outcome.lost)), 'I need a rest.');
    expect(petMessage(const PetState(outcome: Outcome.won)), 'Best day ever!');
    expect(petMessage(const PetState(hunger: 81)), "I'm starving!");
    expect(petMessage(const PetState(happiness: 30)), 'Play with me?');
    expect(petMessage(const PetState(name: 'Mochi', happiness: 60)),
        "Hi, I'm Mochi!");
  });
}
