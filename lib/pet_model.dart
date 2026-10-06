// Pet/game rules, kept free of Flutter widgets so they can be unit tested.
//
// Ownership boundary: this file decides *what* the next pet values are.
// The pet screen's State object owns *when* things happen (timers, taps)
// and stores the current PetState.

const int meterMin = 0;
const int meterMax = 100;

/// Happiness must be strictly above this value to count toward a win.
const int winThreshold = 80;

int clampMeter(int value) => value.clamp(meterMin, meterMax).toInt();

enum Mood { unhappy, neutral, happy }

enum Outcome { playing, won, lost }

class PetState {
  const PetState({
    this.name = 'Pip',
    this.happiness = 50,
    this.hunger = 50,
    this.outcome = Outcome.playing,
  });

  final String name;
  final int happiness;
  final int hunger;
  final Outcome outcome;

  bool get isOver => outcome != Outcome.playing;

  /// "Above 80" means strictly greater than 80.
  bool get qualifiesForWin => happiness > winThreshold;

  /// Same bands drive the mood label, coat tint, and pet scale.
  Mood get mood {
    if (happiness > 70) return Mood.happy;
    if (happiness >= 30) return Mood.neutral;
    return Mood.unhappy;
  }

  PetState copyWith({
    String? name,
    int? happiness,
    int? hunger,
    Outcome? outcome,
  }) {
    return PetState(
      name: name ?? this.name,
      happiness: clampMeter(happiness ?? this.happiness),
      hunger: clampMeter(hunger ?? this.hunger),
      outcome: outcome ?? this.outcome,
    );
  }
}

/// Pure state transitions. Each returns a new PetState and never mutates.
class PetRules {
  static const int feedHungerDrop = 10;
  static const int feedHappinessGain = 10;
  static const int overfedHappinessLoss = 20;
  static const int overfedHungerBelow = 30;
  static const int playHappinessGain = 10;
  static const int playHungerGain = 5;
  static const int tickHungerGain = 5;
  static const int starvingHappinessLoss = 20;

  /// Feeding lowers hunger. If the resulting hunger is below 30 the pet was
  /// overfed and loses happiness; otherwise it gains happiness.
  static PetState feed(PetState s) {
    if (s.isOver) return s;
    final nextHunger = clampMeter(s.hunger - feedHungerDrop);
    final change = nextHunger < overfedHungerBelow
        ? -overfedHappinessLoss
        : feedHappinessGain;
    return _checkLoss(
      s.copyWith(hunger: nextHunger, happiness: s.happiness + change),
    );
  }

  /// Playing raises happiness but makes the pet a little hungrier.
  static PetState play(PetState s) {
    if (s.isOver) return s;
    return _checkLoss(
      s.copyWith(
        happiness: s.happiness + playHappinessGain,
        hunger: s.hunger + playHungerGain,
      ),
    );
  }

  /// One hunger-timer tick. Reaching exactly 100 has no penalty; a tick that
  /// would push hunger past 100 clamps it and costs 20 happiness.
  static PetState hungerTick(PetState s) {
    if (s.isOver) return s;
    if (s.hunger + tickHungerGain > meterMax) {
      return _checkLoss(
        s.copyWith(
          hunger: meterMax,
          happiness: s.happiness - starvingHappinessLoss,
        ),
      );
    }
    return _checkLoss(s.copyWith(hunger: s.hunger + tickHungerGain));
  }

  /// Called when the three-minute high-mood timer completes.
  static PetState win(PetState s) {
    if (s.isOver || !s.qualifiesForWin) return s;
    return s.copyWith(outcome: Outcome.won);
  }

  static PetState rename(PetState s, String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return s;
    return s.copyWith(name: name);
  }

  /// Restores starting meters and clears the outcome; keeps the pet's name.
  static PetState reset(PetState s) => PetState(name: s.name);

  static PetState _checkLoss(PetState s) {
    if (s.hunger == meterMax && s.happiness <= 10) {
      return s.copyWith(outcome: Outcome.lost);
    }
    return s;
  }
}

/// Speech-bubble text derived from state, so it can never drift out of sync.
String petMessage(PetState s, {bool paused = false}) {
  if (s.outcome == Outcome.lost) return 'I need a rest.';
  if (s.outcome == Outcome.won) return 'Best day ever!';
  if (paused) return 'Zzz... (paused)';
  if (s.hunger > 80) return "I'm starving!";
  if (s.happiness <= 30) return 'Play with me?';
  return "Hi, I'm ${s.name}!";
}
