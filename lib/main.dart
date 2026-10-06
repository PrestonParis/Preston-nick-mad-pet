import 'dart:async';

import 'package:flutter/material.dart';

import 'pet_model.dart';

void main() => runApp(const DigitalPetApp());

class DigitalPetApp extends StatelessWidget {
  const DigitalPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

/// Entry screen. Leaving the pet screen (back button) disposes its timers.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Pet')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/pet.png', height: 160, excludeFromSemantics: true),
              const SizedBox(height: 16),
              Text(
                'Keep your pet fed and happy.\n'
                'Stay above 80 happiness for 3 minutes to win!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.pets),
                label: const Text('Visit your pet'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PetScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension MoodView on Mood {
  String get label => switch (this) {
        Mood.happy => 'Happy',
        Mood.neutral => 'Neutral',
        Mood.unhappy => 'Unhappy',
      };

  IconData get icon => switch (this) {
        Mood.happy => Icons.sentiment_very_satisfied,
        Mood.neutral => Icons.sentiment_neutral,
        Mood.unhappy => Icons.sentiment_very_dissatisfied,
      };

  Color get color => switch (this) {
        Mood.happy => Colors.green,
        Mood.neutral => Colors.yellow,
        Mood.unhappy => Colors.red,
      };

  /// Restrained size cue that uses the same bands as the label and tint.
  double get scale => switch (this) {
        Mood.happy => 1.06,
        Mood.neutral => 1.0,
        Mood.unhappy => 0.94,
      };
}

class PetScreen extends StatefulWidget {
  const PetScreen({
    super.key,
    this.hungerInterval = const Duration(seconds: 30),
    this.winDuration = const Duration(minutes: 3),
  });

  // Immutable configuration. Tests pass short durations; the app uses defaults.
  final Duration hungerInterval;
  final Duration winDuration;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  PetState _pet = const PetState();
  bool _paused = false;

  final TextEditingController _nameController =
      TextEditingController(text: 'Pip');

  Timer? _hungerTimer;
  Timer? _winTimer;

  // Short-lived animation state only; never game data.
  bool _bouncing = false;
  Timer? _bounceTimer;
  String _reaction = '';
  bool _reactionVisible = false;
  Timer? _reactionTimer;

  bool get _actionsEnabled => !_pet.isOver && !_paused;

  @override
  void initState() {
    super.initState();
    _startHungerTimer();
  }

  @override
  void dispose() {
    _hungerTimer?.cancel();
    _winTimer?.cancel();
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // ---- Timers -------------------------------------------------------------

  /// Guarantees exactly one hunger timer: always cancel before creating.
  void _startHungerTimer() {
    _hungerTimer?.cancel();
    _hungerTimer = Timer.periodic(widget.hungerInterval, (timer) {
      if (!mounted || _pet.isOver || _paused) {
        timer.cancel();
        return;
      }
      _apply(PetRules.hungerTick(_pet));
    });
  }

  void _cancelWinTimer() {
    _winTimer?.cancel();
    _winTimer = null;
  }

  /// Starts the win timer on the first crossing above 80 and clears it as soon
  /// as happiness returns to 80 or below (or the session stops).
  void _syncWinTimer() {
    if (_pet.isOver || _paused || !_pet.qualifiesForWin) {
      _cancelWinTimer();
      return;
    }
    _winTimer ??= Timer(widget.winDuration, () {
      _winTimer = null;
      if (!mounted) return;
      _apply(PetRules.win(_pet));
    });
  }

  /// Single place where pet state changes. Re-evaluates outcomes every time.
  void _apply(PetState next) {
    setState(() => _pet = next);
    if (_pet.isOver) {
      _hungerTimer?.cancel();
      _cancelWinTimer();
    } else {
      _syncWinTimer();
    }
  }

  // ---- Actions ------------------------------------------------------------

  void _feed() {
    if (!_actionsEnabled) return;
    _apply(PetRules.feed(_pet));
    _celebrate('🍖');
  }

  void _play() {
    if (!_actionsEnabled) return;
    _apply(PetRules.play(_pet));
    _celebrate('🎾');
  }

  void _togglePause() {
    if (_pet.isOver) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _hungerTimer?.cancel();
    } else {
      _startHungerTimer();
    }
    _syncWinTimer();
  }

  void _reset() {
    _cancelWinTimer();
    setState(() {
      _pet = PetRules.reset(_pet);
      _paused = false;
    });
    _startHungerTimer();
    _syncWinTimer();
  }

  void _confirmName() {
    setState(() => _pet = PetRules.rename(_pet, _nameController.text));
    _nameController.text = _pet.name;
    FocusScope.of(context).unfocus();
  }

  /// Bounce + emoji reaction. Replacing the timers means an older callback can
  /// never end a newer bounce or hide a newer reaction.
  void _celebrate(String emoji) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _bounceTimer?.cancel();
    _reactionTimer?.cancel();
    setState(() {
      _bouncing = !reduceMotion;
      _reaction = emoji;
      _reactionVisible = true;
    });
    _bounceTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _bouncing = false);
    });
    _reactionTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _reactionVisible = false);
    });
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Duration motion(int ms) =>
        reduceMotion ? Duration.zero : Duration(milliseconds: ms);
    final mood = _pet.mood;
    final message = petMessage(_pet, paused: _paused);

    return Scaffold(
      appBar: AppBar(title: Text(_pet.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNameField(),
                  const SizedBox(height: 12),
                  if (_pet.isOver) _buildOutcomeBanner(),
                  _buildPet(mood, motion),
                  const SizedBox(height: 8),
                  _buildMoodLabel(mood),
                  const SizedBox(height: 8),
                  _buildSpeech(message, motion),
                  const SizedBox(height: 16),
                  _Meter(
                    label: 'Happiness',
                    value: _pet.happiness,
                    color: mood.color,
                    duration: motion(400),
                  ),
                  const SizedBox(height: 12),
                  _Meter(
                    label: 'Hunger',
                    value: _pet.hunger,
                    color: Colors.orange,
                    duration: motion(400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _winTimer != null
                        ? 'Win streak running — keep happiness above 80!'
                        : 'Keep happiness above 80 for 3 minutes to win.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmName(),
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Pet name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: _confirmName,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildOutcomeBanner() {
    final won = _pet.outcome == Outcome.won;
    return Card(
      color: won ? Colors.green.shade100 : Colors.red.shade100,
      child: ListTile(
        leading: Icon(won ? Icons.emoji_events : Icons.heart_broken,
            color: Colors.black87),
        title: Text(
          won ? 'You win!' : 'Game over',
          style: const TextStyle(color: Colors.black87),
        ),
        subtitle: Text(
          won
              ? '${_pet.name} stayed happy for 3 minutes. Press Reset to play again.'
              : '${_pet.name} got too hungry and sad. Press Reset to try again.',
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildPet(Mood mood, Duration Function(int) motion) {
    final scale = mood.scale * (_bouncing ? 1.12 : 1.0);
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            // Tapping only bounces; it does not change happiness, so taps
            // cannot make the three-minute win trivial.
            onTap: () => _celebrate('❤️'),
            child: AnimatedScale(
              scale: scale,
              duration: motion(180),
              curve: Curves.easeOutBack,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(mood.color, BlendMode.modulate),
                child: Image.asset(
                  'assets/pet.png',
                  height: 200,
                  semanticLabel: '${_pet.name}, ${mood.label.toLowerCase()}',
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 40,
            child: ExcludeSemantics(
              child: AnimatedSlide(
                offset: _reactionVisible ? Offset.zero : const Offset(0, 0.6),
                duration: motion(250),
                child: AnimatedOpacity(
                  opacity: _reactionVisible ? 1 : 0,
                  duration: motion(250),
                  child: Text(_reaction, style: const TextStyle(fontSize: 40)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodLabel(Mood mood) {
    return Semantics(
      label: 'Mood: ${mood.label}',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(mood.icon, size: 28),
          const SizedBox(width: 6),
          Text('Mood: ${mood.label}',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildSpeech(String message, Duration Function(int) motion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        liveRegion: true,
        child: AnimatedSwitcher(
          duration: motion(300),
          child: Text(
            message,
            key: ValueKey(message),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _actionsEnabled ? _feed : null,
          icon: const Icon(Icons.restaurant),
          label: const Text('Feed'),
        ),
        FilledButton.icon(
          onPressed: _actionsEnabled ? _play : null,
          icon: const Icon(Icons.sports_baseball),
          label: const Text('Play'),
        ),
        OutlinedButton.icon(
          onPressed: _pet.isOver ? null : _togglePause,
          icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          label: Text(_paused ? 'Resume' : 'Pause'),
        ),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
        ),
      ],
    );
  }
}

/// Progress bar that glides to the current value. The number shown always
/// comes straight from state; only the bar animates.
class _Meter extends StatelessWidget {
  const _Meter({
    required this.label,
    required this.value,
    required this.color,
    required this.duration,
  });

  final String label;
  final int value;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value out of 100',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text('$value / 100'),
            ],
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value / 100),
            duration: duration,
            curve: Curves.easeOut,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
