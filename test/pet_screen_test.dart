import 'package:digital_pet/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tick = Duration(seconds: 1);
const winTime = Duration(seconds: 3);

Future<void> pumpPet(WidgetTester tester,
    {Duration hunger = tick, Duration win = winTime}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: PetScreen(hungerInterval: hunger, winDuration: win),
  ));
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

bool isEnabled(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(button).enabled;
}

void main() {
  testWidgets('hunger timer adds 5 per interval', (tester) async {
    await pumpPet(tester);
    expect(find.text('50 / 100'), findsNWidgets(2));
    await tester.pump(tick);
    expect(find.text('55 / 100'), findsOneWidget); // hunger
  });

  testWidgets('pause stops the hunger timer and disables care actions',
      (tester) async {
    await pumpPet(tester);
    await tap(tester, 'Pause');
    expect(isEnabled(tester, 'Feed'), isFalse);
    await tester.pump(tick * 5);
    expect(find.text('50 / 100'), findsNWidgets(2));
    await tap(tester, 'Resume');
    await tester.pump(tick);
    expect(find.text('55 / 100'), findsOneWidget);
  });

  testWidgets('win after continuous time above 80; dropping to 80 cancels',
      (tester) async {
    await pumpPet(tester, hunger: const Duration(hours: 1));
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Play'); // happiness 90, hunger 70
    }
    for (var i = 0; i < 4; i++) {
      await tap(tester, 'Feed'); // hunger 30, happiness 100
    }
    await tester.pump(winTime - const Duration(milliseconds: 10));
    await tap(tester, 'Feed'); // hunger 20 (<30) -> happiness 80
    expect(find.text('80 / 100'), findsOneWidget);
    await tester.pump(winTime * 2);
    expect(find.text('You win!'), findsNothing);

    await tap(tester, 'Play'); // happiness 90: fresh timer starts
    await tester.pump(winTime - const Duration(milliseconds: 10));
    expect(find.text('You win!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('You win!'), findsOneWidget);
    expect(isEnabled(tester, 'Feed'), isFalse);
    expect(isEnabled(tester, 'Play'), isFalse);
  });

  testWidgets('starving leads to game over and freezes state', (tester) async {
    await pumpPet(tester);
    // 10 ticks: hunger 50 -> 100; 2 overflow ticks: happiness 50 -> 10.
    for (var i = 0; i < 12; i++) {
      await tester.pump(tick);
    }
    expect(find.text('Game over'), findsOneWidget);
    expect(find.text('10 / 100'), findsOneWidget);
    expect(isEnabled(tester, 'Feed'), isFalse);
    await tester.pump(tick * 5);
    expect(find.text('10 / 100'), findsOneWidget);

    await tap(tester, 'Reset');
    expect(find.text('Game over'), findsNothing);
    expect(find.text('50 / 100'), findsNWidgets(2));
    await tester.pump(tick);
    expect(find.text('55 / 100'), findsOneWidget); // exactly one timer
  });

  testWidgets('confirming a name updates the pet', (tester) async {
    await pumpPet(tester);
    await tester.enterText(find.byType(TextField), 'Mochi');
    await tap(tester, 'Confirm');
    expect(find.text("Hi, I'm Mochi!"), findsOneWidget);
  });

  testWidgets('leaving the pet screen cancels its timers', (tester) async {
    await tester.pumpWidget(const DigitalPetApp());
    await tester.tap(find.text('Visit your pet'));
    await tester.pumpAndSettle();
    expect(find.text('Feed'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    // A post-dispose setState would throw here.
    await tester.pump(const Duration(minutes: 5));
    expect(tester.takeException(), isNull);
  });
}
