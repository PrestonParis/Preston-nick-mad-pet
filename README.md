# Digital Pet — In-Class Activity 07

A Flutter pet-care app where taps and time change a pet's state. It uses `StatefulWidget`, `setState()`, timers that start in `initState()` and stop in `dispose()`, and mood feedback that doesn't rely on color alone.

- **Repository:** _TODO: shared repo URL_
- **APK:** `DigitalPet_<TeamName>.apk` (submitted separately to iCollege)

## Team

| Member | Team | Role | Pathway | Contribution (issues / PRs) |
|---|---|---|---|---|
| Preston Paris | _Team 1 / 2_ | _role_ | Undergraduate | _links_ |
| _name_ | | | | |

- **Team 1 · Care Systems:** feed/play/reset, bounded meters, hunger and win timers, outcomes, state tests.
- **Team 2 · Pet Personality:** derived messages, mood feedback, pet asset, motion/accessibility polish, interaction tests.

## Setup, run, test, build

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

## Project structure

| File | Responsibility |
|---|---|
| `lib/pet_model.dart` | Pure-Dart game rules: `PetState`, `PetRules` (feed, play, hunger tick, win, reset, rename), clamping, mood bands, and the derived `petMessage`. Contains no widgets. |
| `lib/main.dart` | `HomeScreen` and `PetScreen`. The pet screen's `State` holds the current `PetState`, owns the timers and text controller, and renders the UI. |
| `test/pet_model_test.dart` | Unit tests for boundaries, mood thresholds, overflow ticks, outcomes, and reset. |
| `test/pet_screen_test.dart` | Widget tests that run the real timers with short durations: hunger ticks, pause, win, win cancellation, loss, reset, renaming, and disposal. |

`PetScreen` takes `hungerInterval` (default 30 s) and `winDuration` (default 3 min) as immutable constructor parameters. Tests pass short values, and the app always uses the production defaults, so nothing needs to be changed back before a release build.

## Game rules

| Event | Effect |
|---|---|
| Start / Reset | Happiness 50, hunger 50, outcome cleared, name kept, win timer cancelled, exactly one hunger timer restarted. |
| Feed | Hunger −10. If the resulting hunger is below 30 (overfed), happiness −20; otherwise happiness +10. |
| Play | Happiness +10, hunger +5. |
| Hunger tick (every 30 s) | Hunger +5. If a tick would push hunger past 100, hunger is clamped to 100 and happiness drops by 20. Going from 95 to 100 has no penalty. |
| Tap pet | Bounce and ❤️ only. Happiness doesn't change, so tapping can't make the win trivial. |
| Win | Happiness stays **strictly above 80** for 3 continuous minutes. The timer starts on the first crossing above 80 and is cancelled as soon as happiness drops to 80 or below. |
| Loss | Hunger is 100 and happiness is 10 or lower. |
| After win/loss | Feed, Play, and Pause are disabled and both timers stop until Reset. |

All meters are clamped to 0–100 in `PetState.copyWith`.

**Mood bands** (these drive the label, icon, tint, and scale): above 70 is Happy (green, 1.06×), 30–70 is Neutral (yellow, 1.0×), below 30 is Unhappy (red, 0.94×).

## Advanced features (undergraduate: 2)

| Feature | User flow | State changes and why | Learning outcome | Evidence |
|---|---|---|---|---|
| **Session controls** (Pause/Resume) | Tap Pause: Feed and Play are disabled and the pet says "Zzz... (paused)". Tap Resume to continue. | `_paused` is set inside `setState`. Pausing cancels the hunger timer and the win timer. Resuming starts a new hunger timer (cancelling any old one first) and, if happiness is still above 80, starts a fresh 3-minute win streak, because a paused streak isn't continuous. | Timer lifecycle; one source of truth | Widget test `pause stops the hunger timer…`; manual notes below |
| **Visual polish & accessible motion** | Feed, Play, or tap the pet to see the bounce and emoji. Meters glide, and the speech bubble cross-fades. | Action bounce (`AnimatedScale` plus a replaceable timer). Action reactions 🍖🎾❤️ (`AnimatedSlide` + `AnimatedOpacity`). Living meters (`TweenAnimationBuilder`). Expression switch (`AnimatedSwitcher` keyed on the message). Mood tint and size. Reduced motion: `MediaQuery.disableAnimations` sets every duration to zero and turns off the bounce. Only short-lived animation flags are stored. Mood, color, scale, and message are all derived from `PetState`. | UI derived from state; delayed callbacks respect the lifecycle | Threshold unit test (29/30/70/71); manual notes below |

## Test evidence

### Automated (`flutter test`)

```
00:00 +20: All tests passed!
```

### Manual test matrix (fill in on device)

| Scenario | Expected | Result / values |
|---|---|---|
| Feed at hunger 5; feed at hunger 95 | 5 → 0 (happiness −20); 95 → 85 (happiness +10) | Unit-tested ✅ · device: |
| Play at happiness 95 | Happiness clamps to 100 | Unit-tested ✅ · device: |
| Happiness 29 / 30 / 70 / 71 | Red Unhappy / yellow Neutral / yellow Neutral / green Happy, with the text label always shown | Unit-tested ✅ · screenshots: |
| Above 80 for 2:59, then drop to 80 | No win; streak message cleared | Widget-tested ✅ · device: |
| Above 80 again for 3:00 | Win; hunger timer stops | Widget-tested ✅ · device: |
| Hunger 95 → 100 → another tick | No penalty, then happiness −20 | Unit-tested ✅ · device: |
| Hunger 100 and happiness 10 | Game over; values frozen until Reset | Widget-tested ✅ · device: |
| Leave the pet screen with the timer running | No post-dispose errors | Widget-tested ✅ · console: |
| Reduced motion on / off | No bounce or slide when on; messages and meters still update | device: |
| Release APK smoke test | Installs, launches, core actions work | device: |

## Collaboration evidence

- Issues: _links_
- Team 1 PR: _link_ (reviewed by _Team 2 member_)
- Team 2 PR: _link_ (reviewed by _Team 1 member_)

## Screenshots

_Add real screenshots (happy / neutral / unhappy / win / game over)._

## Asset license

`assets/pet.png` is an original drawing made for this project (generated with Python/Pillow by the team) and is free to use in this repository. It is a light grayscale image so that `BlendMode.modulate` tints it clearly.
