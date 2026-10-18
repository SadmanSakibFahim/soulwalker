import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/dev/dev_host.dart';
import 'package:soulwalker/domain/progress.dart';
import 'package:soulwalker/domain/terminology_resolver.dart';
import 'package:soulwalker/presentation/screens/v1_screens.dart';

TerminologyResolver _terms() {
  return TerminologyResolver(const <String, String>{
    'PLAYER_TITLE': 'the Half-Woken',
    'CHECKPOINT_NAME': 'a Held Breath',
    'DEATH_MARKER_NAME': 'a Failed Waking',
    'AFFLICTION_NAME': 'the Weight',
    'ARMAMENT_CATEGORY_WEAPON': 'Wakings',
    'ARMAMENT_CATEGORY_ARMOR': 'Linens',
    'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    'SUMMONS_NAME': 'a Shared Vigil',
    'STANDINGS_NAME': 'the Quiet Census',
  });
}

void main() {
  testWidgets('dev panel adds kilometres onto the checkpoint copy', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DevHost(terms: _terms())));
    await tester.tap(find.text('+1 km'));
    await tester.pump();
    expect(find.textContaining('Walked 1.0 km'), findsWidgets);
    expect(find.text('Wakings'), findsNothing);
  });

  testWidgets('five kilometres counts the day and unlocks both armaments',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DevHost(terms: _terms())));
    await tester.tap(find.text('+5 km'));
    await tester.pump();
    expect(find.textContaining('day 1 of 5'), findsOneWidget);
    expect(find.text('Wakings'), findsOneWidget);
    expect(find.text('Linens'), findsOneWidget);
  });

  testWidgets('closing a missed day ends the attempt and keeps distance',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DevHost(terms: _terms())));
    await tester.tap(find.text('+5 km'));
    await tester.pump();
    await tester.tap(find.text('Close day'));
    await tester.pump();
    await tester.tap(find.text('Close day'));
    await tester.pump();
    expect(find.textContaining('Walked 5.0 km'), findsWidgets);
    expect(find.textContaining('attempt 2'), findsOneWidget);
    expect(find.textContaining('The attempt ended'), findsOneWidget);
    expect(find.text('Linens'), findsOneWidget);
  });

  testWidgets('death marker screen lists fixed-type attempts', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeathMarkerScreen(
          terms: _terms(),
          markers: const <DeathMarkerView>[DeathMarkerView(attemptNumber: 3)],
        ),
      ),
    );
    expect(find.text('a Failed Waking'), findsOneWidget);
    expect(find.text('Died here, attempt #3'), findsOneWidget);
  });
}
